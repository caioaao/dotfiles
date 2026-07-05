// Package distill turns raw session activity into semantic feed lines.
//
// Mechanical items (prompts, done, errors, compaction, branch switches)
// bypass the LLM. Turns are batched in chunks and distilled by a small
// model that receives its own rolling state summary + the feed tail + the
// new delta, and returns 0..n lines plus the updated state. Emitting
// nothing is the common, correct output - feed quality equals suppression
// quality.
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

const systemPrompt = `You distill a coding agent's raw activity into a terse, high-signal feed for a human glancing at a monitor. The human wants the big picture: what phase the agent is in, key decisions, surprises, reversals - never mechanics.

You receive:
- STATE: your own rolling summary from previous calls (empty on first call)
- FEED TAIL: recent feed lines already shown to the human
- NEW ACTIVITY: new agent turns (reasoning excerpts, tool calls with results)

Respond with strict JSON only, no markdown fences, no prose:
{"lines":[{"kind":"phase|insight|backtrack|note","text":"...","detail":"..."}],"state":"..."}

Rules for "lines":
- Emit a line ONLY when the big picture changed. An empty array is the common, correct output.
- kind "phase": agent entered a new phase (researching X, designing Y, implementing Z, debugging W, verifying).
- kind "insight": standalone reasoning nugget - a realization, key decision, discovered constraint.
- kind "backtrack": agent reversed course, abandoned an approach, or discovered its assumption was wrong.
- kind "note": anything else worth one glance.
- "text": ONE terse line, max 12 words / 100 characters. "Exploring binary search over commit range" - never generic filler like "working on the task", never multiple sentences. Anything longer belongs in "detail". Inline markdown code spans (backticks) are welcome for identifiers, paths, and commands.
- "detail" (optional): 1-3 sentences of genuinely interesting reasoning - why this approach, the rejected alternative, the surprise. Omit by default. "text" must stand alone without it. Never fabricate reasoning that is not in the activity. Markdown is allowed here: inline code and short lists (2-3 items) render well; avoid headings and code fences.
- Never restate what FEED TAIL already says. Never narrate tool mechanics ("ran grep", "read file").

Rules for "state": updated rolling summary, max 400 chars: current goal, chosen approach, position in the plan. Always provide it.`

type Config struct {
	Provider  string `json:"provider"`
	ModelID   string `json:"modelId"`
	MaxTokens int    `json:"maxTokens"`
}

func LoadConfig() Config {
	cfg := Config{Provider: "anthropic", ModelID: "claude-haiku-4-5", MaxTokens: 1024}
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

	rollingState := wm.State
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
			entries, newState, err := d.distillChunk(ctx, chunk, rollingState, feedTail)
			if err != nil {
				return err
			}
			rollingState = newState
			chunkUpTo := chunk[len(chunk)-1].UpTo
			for i := range entries {
				entries[i].UpTo = chunkUpTo
			}
			if err := emit(entries); err != nil {
				return err
			}
			if err := d.st.WriteState(id, store.DistillerState{UpTo: chunkUpTo, State: rollingState}); err != nil {
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
		if err := d.st.WriteState(id, store.DistillerState{UpTo: item.UpTo, State: rollingState}); err != nil {
			return count, err
		}
	}
	if err := flushTurns(); err != nil {
		return count, err
	}
	if err := d.st.WriteState(id, store.DistillerState{UpTo: res.UpTo, State: rollingState}); err != nil {
		return count, err
	}
	return count, nil
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
	rollingState string,
	feedTail []store.FeedEntry,
) ([]store.FeedEntry, string, error) {
	var tailLines []string
	for _, e := range feedTail {
		tailLines = append(tailLines, fmt.Sprintf("[%s] %s: %s", hhmm(e.T), e.Kind, e.Text))
	}
	state := rollingState
	if state == "" {
		state = "(none - first call)"
	}
	tail := strings.Join(tailLines, "\n")
	if tail == "" {
		tail = "(empty)"
	}
	prompt := strings.Join([]string{
		"STATE: " + state,
		"",
		"FEED TAIL:",
		tail,
		"",
		"NEW ACTIVITY:",
		session.RenderItems(turns),
	}, "\n")

	raw, err := d.llm.complete(ctx, systemPrompt, prompt)
	if err != nil {
		return nil, "", err
	}
	entries, newState := parseResponse(raw, rollingState, turns[len(turns)-1].T)
	return entries, newState, nil
}

var llmKinds = map[store.FeedKind]bool{
	store.KindPhase:     true,
	store.KindInsight:   true,
	store.KindNote:      true,
	store.KindBacktrack: true,
}

func parseResponse(raw, previousState, t string) ([]store.FeedEntry, string) {
	var parsed struct {
		Lines []struct {
			Kind   string `json:"kind"`
			Text   string `json:"text"`
			Detail string `json:"detail"`
		} `json:"lines"`
		State *string `json:"state"`
	}
	if err := json.Unmarshal([]byte(stripFences(raw)), &parsed); err != nil {
		// Unparseable output: keep state, emit nothing. Source is
		// preserved; a redistill can always retry.
		return nil, previousState
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
	state := previousState
	if parsed.State != nil {
		state = text.Truncate(*parsed.State, 500)
	}
	return entries, state
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
