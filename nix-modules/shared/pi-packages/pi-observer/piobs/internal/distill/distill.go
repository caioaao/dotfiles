// Package distill turns raw session activity into semantic feed lines.
//
// Mechanical items (prompts, done, errors, compaction, branch switches)
// bypass the LLM. Turns are batched in chunks and narrated by a small
// model that receives its own previous living doc + the feed tail + the
// new delta, and returns the rewritten doc plus 0..n beat lines.
// Emitting no lines is the common, correct output - ticker quality
// equals suppression quality. The doc, by contrast, is rewritten in
// full every pass: narration needs revision.
//
// Idempotency: every feed line carries upTo (session-file byte offset).
// The watermark rule lives in store.Watermark (see CONTRACT.md).
package distill

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"piobs/internal/session"
	"piobs/internal/store"
	"piobs/internal/text"
)

const (
	chunkTurns    = 15
	feedTailLines = 10
)

const systemPrompt = `You are the narrator of a live coding-agent session. You maintain a living brief - the document a colleague would want after asking "what is that agent up to?" - plus a terse beat ticker. Describe the evolution of the TASK, never the mechanics of the conversation.

You receive:
- DOC: your own previous document (empty on first call)
- FEED TAIL: recent beat lines already shown to the human
- NEW ACTIVITY: new agent turns (reasoning excerpts, tool calls with results, user messages)

Respond with strict JSON only, no markdown fences, no prose:
{"doc":{"title":"...","now":"...","waiting":"...","sections":[{"kind":"plan","items":[{"state":"done","text":"..."}]}],"story":"..."},"lines":[{"kind":"phase|insight|backtrack|note","text":"...","detail":"..."}]}

Rules for "doc" - rewrite the WHOLE document every time, revising freely as the story develops:
- "title": 3-8 words naming the TASK the session is about ("ledger-link SQL migration"), never the current activity and never conversation mechanics. Keep the SAME title as the previous DOC unless the task genuinely pivoted - stability beats novelty.
- "now": 1-2 present-tense sentences. What the agent is doing right now and why. Specific: "Rewriting the feed renderer around zoom levels; chasing a double-render bug in the fold cache" - never "working on the task".
- "waiting" (omit unless true): set ONLY when the agent has stopped and needs the human - asked a question, presented options, finished and awaits direction. One sentence stating exactly what it needs.
- "sections": 0-3 sections, only kinds that genuinely fit the session right now:
  * "plan": the agent follows a plan or slice list. items with state done|doing|todo.
  * "hypotheses": debugging loop. items with state open|ruledout|confirmed.
  * "findings": research/exploration. items are discovered facts.
  * "decisions": design work. items are "chose X over Y because Z".
  * "risks": known hazards or unresolved doubts.
  Keep the SAME sections as the previous DOC unless the session's mode genuinely changed - stability beats novelty. Max ~7 items per section; merge or drop stale items when rewriting.
- "story": 3-8 past-tense sentences narrating how the task evolved: the arc, dead ends acknowledged ("the trigger approach died on a deadlock"), user redirections woven in ("the user redirected toward vertical slices"). Compress older material harder on every rewrite; recent developments get the detail.
- Complete sentences everywhere. Write to fit the budget - never rely on being cut off.

Rules for "lines" (the beat ticker):
- Emit a line ONLY when the big picture changed. An empty array is the common, correct output.
- kind "phase": agent entered a new phase (researching X, designing Y, implementing Z, debugging W, verifying).
- kind "insight": standalone reasoning nugget - a realization, key decision, discovered constraint.
- kind "backtrack": agent reversed course, abandoned an approach, or discovered its assumption was wrong.
- kind "note": anything else worth one glance.
- "text": ONE terse line, max 12 words / 100 characters. Anything longer belongs in "detail". Inline markdown code spans (backticks) are welcome for identifiers, paths, and commands.
- "detail" (optional): 1-3 sentences of genuinely interesting reasoning. Omit by default. "text" must stand alone without it. Never fabricate reasoning that is not in the activity.
- Never restate what FEED TAIL already says. Never narrate tool mechanics ("ran grep", "read file").`

type Config struct {
	Provider  string `json:"provider"`
	ModelID   string `json:"modelId"`
	MaxTokens int    `json:"maxTokens"`
}

func LoadConfig() Config {
	// 2048: the doc rewrite plus beat lines routinely overflow 1024.
	cfg := Config{Provider: "anthropic", ModelID: "claude-haiku-4-5", MaxTokens: 2048}
	home, err := os.UserHomeDir()
	if err != nil {
		return cfg
	}
	raw, err := os.ReadFile(filepath.Join(home, ".config", "pi-observer", "config.json"))
	if err != nil {
		return cfg
	}
	_ = json.Unmarshal(raw, &cfg) // partial configs overlay the defaults
	return cfg
}

// completer is the one seam to the LLM: system+prompt in, raw text out.
// Implemented by the anthropic client; stubbed in tests.
type completer interface {
	complete(ctx context.Context, system, prompt string) (string, error)
}

// Distiller distills pending session activity into the feed. Provider
// plumbing is an implementation detail behind New.
type Distiller struct {
	st  *store.Store
	llm completer
}

// New builds a Distiller for the configured provider. Only "anthropic"
// is supported in v1; anything else is a loud error, never a silent POST
// to the wrong endpoint.
func New(st *store.Store, cfg Config) (*Distiller, error) {
	if cfg.Provider != "anthropic" {
		return nil, fmt.Errorf("unsupported provider %q (v1 supports only \"anthropic\")", cfg.Provider)
	}
	llm, err := newAnthropicClient(cfg)
	if err != nil {
		return nil, err
	}
	return &Distiller{st: st, llm: llm}, nil
}

// Session distills everything pending for a session. Returns the number
// of new feed entries. onEntry (optional) observes each appended entry.
func (d *Distiller) Session(ctx context.Context, doc store.SessionInfo, onEntry func(store.FeedEntry)) (int, error) {
	if doc.SessionFile == "" {
		return 0, nil
	}
	id := doc.SessionID
	wm := d.st.Watermark(id)
	res := session.ParseSince(doc.SessionFile, wm.UpTo)
	if len(res.Items) == 0 {
		if res.UpTo > wm.UpTo {
			if err := d.st.WriteState(id, store.DistillerState{UpTo: res.UpTo, State: wm.State}); err != nil {
				return 0, err
			}
		}
		return 0, nil
	}

	rollingDoc := wm.Doc
	feedTail := tailOf(d.st.ReadFeed(id))
	count := 0

	emit := func(entries []store.FeedEntry) error {
		if err := d.st.AppendFeed(id, entries); err != nil {
			return err
		}
		for _, e := range entries {
			if onEntry != nil {
				onEntry(e)
			}
		}
		feedTail = tailOf(append(feedTail, entries...))
		count += len(entries)
		return nil
	}

	// Process in order; batch consecutive turns, flush the batch through
	// the LLM before any mechanical entry so feed order matches reality.
	var turnBuffer []*session.ActivityItem
	flushTurns := func() error {
		for len(turnBuffer) > 0 {
			// Cancellation must be observed between chunks, not only
			// inside the HTTP call: a cancelled distill must stop
			// appending/advancing state (the TUI may have cleared the
			// feed for a redistill).
			if err := ctx.Err(); err != nil {
				return err
			}
			n := min(chunkTurns, len(turnBuffer))
			chunk := turnBuffer[:n]
			turnBuffer = turnBuffer[n:]
			entries, newDoc, err := d.distillChunk(ctx, chunk, rollingDoc, feedTail)
			if err != nil {
				return err
			}
			rollingDoc = newDoc
			chunkUpTo := chunk[len(chunk)-1].UpTo
			for i := range entries {
				entries[i].UpTo = chunkUpTo
			}
			if err := emit(entries); err != nil {
				return err
			}
			if err := d.st.WriteState(id, stateFor(chunkUpTo, rollingDoc)); err != nil {
				return err
			}
		}
		return nil
	}

	for _, item := range res.Items {
		if err := ctx.Err(); err != nil {
			return count, err
		}
		if item.Type == session.Turn {
			turnBuffer = append(turnBuffer, item)
			continue
		}
		if err := flushTurns(); err != nil {
			return count, err
		}
		if err := emit([]store.FeedEntry{mechanicalEntry(item)}); err != nil {
			return count, err
		}
		if err := d.st.WriteState(id, stateFor(item.UpTo, rollingDoc)); err != nil {
			return count, err
		}
	}
	if err := flushTurns(); err != nil {
		return count, err
	}
	if err := d.st.WriteState(id, stateFor(res.UpTo, rollingDoc)); err != nil {
		return count, err
	}
	return count, nil
}

// stateFor derives the persisted state from the rolling doc. State (the
// short summary string) mirrors Doc.Now for backward compatibility;
// list titles now come from Doc.Title, with State as the legacy
// fallback.
func stateFor(upTo int64, doc *store.SessionDoc) store.DistillerState {
	st := store.DistillerState{UpTo: upTo, Doc: doc}
	if doc != nil {
		st.State = text.Truncate(doc.Now, 500)
	}
	return st
}

func tailOf(entries []store.FeedEntry) []store.FeedEntry {
	if len(entries) > feedTailLines {
		entries = entries[len(entries)-feedTailLines:]
	}
	// copy: callers append to the result
	return append([]store.FeedEntry(nil), entries...)
}

func mechanicalEntry(item *session.ActivityItem) store.FeedEntry {
	if item.Type == session.Prompt {
		return store.FeedEntry{T: item.T, Kind: store.KindPrompt, Text: item.Text, UpTo: item.UpTo}
	}
	var kind store.FeedKind
	switch item.Kind {
	case session.MarkerDone:
		kind = store.KindDone
	case session.MarkerError:
		kind = store.KindError
	case session.MarkerBranch:
		kind = store.KindBacktrack
	default:
		kind = store.KindNote
	}
	return store.FeedEntry{T: item.T, Kind: kind, Text: item.Text, UpTo: item.UpTo}
}

func (d *Distiller) distillChunk(
	ctx context.Context,
	turns []*session.ActivityItem,
	rollingDoc *store.SessionDoc,
	feedTail []store.FeedEntry,
) ([]store.FeedEntry, *store.SessionDoc, error) {
	var tailLines []string
	for _, e := range feedTail {
		tailLines = append(tailLines, fmt.Sprintf("[%s] %s: %s", hhmm(e.T), e.Kind, e.Text))
	}
	docJSON := "(none - first call)"
	if rollingDoc != nil {
		if b, err := json.Marshal(rollingDoc); err == nil {
			docJSON = string(b)
		}
	}
	tail := strings.Join(tailLines, "\n")
	if tail == "" {
		tail = "(empty)"
	}
	prompt := strings.Join([]string{
		"DOC: " + docJSON,
		"",
		"FEED TAIL:",
		tail,
		"",
		"NEW ACTIVITY:",
		session.RenderItems(turns),
	}, "\n")

	raw, err := d.llm.complete(ctx, systemPrompt, prompt)
	if err != nil {
		return nil, nil, err
	}
	entries, newDoc := parseResponse(raw, rollingDoc, turns[len(turns)-1].T)
	return entries, newDoc, nil
}

var llmKinds = map[store.FeedKind]bool{
	store.KindPhase:     true,
	store.KindInsight:   true,
	store.KindNote:      true,
	store.KindBacktrack: true,
}

func parseResponse(raw string, previousDoc *store.SessionDoc, t string) ([]store.FeedEntry, *store.SessionDoc) {
	var parsed struct {
		Doc   *store.SessionDoc `json:"doc"`
		Lines []struct {
			Kind   string `json:"kind"`
			Text   string `json:"text"`
			Detail string `json:"detail"`
		} `json:"lines"`
	}
	if err := json.Unmarshal([]byte(stripFences(raw)), &parsed); err != nil {
		// Unparseable output: keep the doc, emit nothing. Source is
		// preserved; a redistill can always retry.
		return nil, previousDoc
	}
	var entries []store.FeedEntry
	for _, line := range parsed.Lines {
		txt := strings.TrimSpace(line.Text)
		if txt == "" {
			continue
		}
		kind := store.FeedKind(line.Kind)
		if !llmKinds[kind] {
			kind = store.KindNote
		}
		// 120 backstops the prompt's 100-char rule: a model that ignores
		// it gets clipped, not a paragraph in the feed.
		entry := store.FeedEntry{T: t, Kind: kind, Text: text.Truncate(txt, 120)}
		if detail := strings.TrimSpace(line.Detail); detail != "" {
			entry.Detail = text.Truncate(detail, 600)
		}
		entries = append(entries, entry)
	}
	doc := previousDoc
	if parsed.Doc != nil && strings.TrimSpace(parsed.Doc.Now) != "" {
		doc = sanitizeDoc(parsed.Doc)
	}
	return entries, doc
}

// Doc budgets are corruption backstops, not layout: the prompt's
// sentence budgets do the real work, these keep a runaway model from
// flooding state.json.
const (
	docTitleBudget   = 80
	docNowBudget     = 400
	docWaitingBudget = 400
	docStoryBudget   = 2500
	docTextBudget    = 1500
	docItemBudget    = 250
	docMaxSections   = 5
	docMaxItems      = 10
)

func sanitizeDoc(d *store.SessionDoc) *store.SessionDoc {
	out := &store.SessionDoc{
		Title:   text.Truncate(strings.TrimSpace(d.Title), docTitleBudget),
		Now:     text.Truncate(strings.TrimSpace(d.Now), docNowBudget),
		Waiting: text.Truncate(strings.TrimSpace(d.Waiting), docWaitingBudget),
		Story:   text.Truncate(strings.TrimSpace(d.Story), docStoryBudget),
	}
	for _, s := range d.Sections {
		if len(out.Sections) == docMaxSections {
			break
		}
		sec := store.DocSection{
			Kind: strings.TrimSpace(s.Kind),
			Text: text.Truncate(strings.TrimSpace(s.Text), docTextBudget),
		}
		for _, it := range s.Items {
			txt := strings.TrimSpace(it.Text)
			if txt == "" || len(sec.Items) == docMaxItems {
				continue
			}
			sec.Items = append(sec.Items, store.DocItem{
				State: strings.TrimSpace(it.State),
				Text:  text.Truncate(txt, docItemBudget),
			})
		}
		if sec.Kind == "" || (sec.Text == "" && len(sec.Items) == 0) {
			continue
		}
		out.Sections = append(out.Sections, sec)
	}
	return out
}

var fenceRe = regexp.MustCompile("(?s)^```(?:json)?\\s*(.*?)\\s*```$")

func stripFences(s string) string {
	trimmed := strings.TrimSpace(s)
	if m := fenceRe.FindStringSubmatch(trimmed); m != nil {
		return m[1]
	}
	return trimmed
}

func hhmm(iso string) string {
	if len(iso) >= 16 {
		return iso[11:16]
	}
	return iso
}
