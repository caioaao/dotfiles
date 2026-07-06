// Package store implements the CLI side of the pi-observer data-dir
// contract (see ../../CONTRACT.md): registry read + liveness, feed
// append/read, distiller state, the crash-safe watermark, and gc.
//
// Ownership per contract: this package writes only feed/, except gc,
// which additionally deletes sessions/ docs for long-dead sessions.
package store

import (
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const SchemaVersion = 1

type SessionState string

const (
	Working SessionState = "working"
	Idle    SessionState = "idle"
	Exited  SessionState = "exited"
)

type TmuxRef struct {
	Pane string `json:"pane"`
}

// RegistryDoc mirrors CONTRACT.md's RegistryDoc. Nullable strings decode
// as "" (JSON null leaves the zero value).
type RegistryDoc struct {
	SchemaVersion   int          `json:"schemaVersion"`
	SessionID       string       `json:"sessionId"`
	PID             int          `json:"pid"`
	PPID            int          `json:"ppid"`         // 0 when absent (older docs)
	PIDStartedAt    float64      `json:"pidStartedAt"` // epoch ms, may be fractional
	Cwd             string       `json:"cwd"`
	SessionFile     string       `json:"sessionFile"`
	SessionName     string       `json:"sessionName"`
	Model           string       `json:"model"`
	Tmux            *TmuxRef     `json:"tmux"`
	State           SessionState `json:"state"`
	CurrentActivity string       `json:"currentActivity"`
	StartedAt       string       `json:"startedAt"`
	UpdatedAt       string       `json:"updatedAt"`
	LastPrompt      string       `json:"lastPrompt"`
}

// SessionInfo is a RegistryDoc with the registry state corrected by the
// pid identity check and parentage resolved against sibling docs.
type SessionInfo struct {
	RegistryDoc
	EffectiveState SessionState
	// ParentID is the sessionId of the session whose pid equals this
	// doc's ppid: subagents are direct children of the spawning pi
	// (CONTRACT.md "Parentage"). Empty for top-level sessions.
	ParentID string
}

type FeedKind string

const (
	KindPhase     FeedKind = "phase"
	KindInsight   FeedKind = "insight"
	KindNote      FeedKind = "note"
	KindBacktrack FeedKind = "backtrack"
	KindDone      FeedKind = "done"
	KindError     FeedKind = "error"
	KindPrompt    FeedKind = "prompt"
)

type FeedEntry struct {
	T      string   `json:"t"`
	Kind   FeedKind `json:"kind"`
	Text   string   `json:"text"`
	Detail string   `json:"detail,omitempty"`
	// UpTo is the session-file byte offset this line covers; it makes
	// distillation idempotent.
	UpTo int64 `json:"upTo"`
}

type DistillerState struct {
	UpTo int64 `json:"upTo"`
	// State is a short rolling summary (mirrors Doc.Now), kept for
	// backward compatibility and cheap list titles.
	State string `json:"state"`
	// Doc is the distiller's living brief: rewritten in full on every
	// distill pass. Nil until the first LLM chunk completes.
	Doc *SessionDoc `json:"doc,omitempty"`
}

// SessionDoc is the narrator's document: fixed skeleton (now, waiting,
// story), adaptive middle (sections). The distiller rewrites the whole
// doc each pass - narration needs revision, which append-only feed
// lines cannot express.
type SessionDoc struct {
	// Title: 3-8 words naming the task (not the current activity),
	// stable across rewrites. List/header identity line.
	Title string `json:"title,omitempty"`
	// Now: 1-2 present-tense sentences - what the agent is doing and why.
	Now string `json:"now"`
	// Waiting: set only when the agent stopped and needs the human.
	Waiting string `json:"waiting,omitempty"`
	// Sections is the adaptive middle: plan, hypotheses, findings,
	// decisions, risks. Unknown kinds render as titled prose.
	Sections []DocSection `json:"sections,omitempty"`
	// Story: past-tense narrative of how the task evolved; older
	// material compresses more on each rewrite.
	Story string `json:"story"`
}

// Known DocSection kinds. Open enum: readers render unknown kinds as
// titled prose instead of dropping them.
const (
	SectionPlan       = "plan"
	SectionHypotheses = "hypotheses"
	SectionFindings   = "findings"
	SectionDecisions  = "decisions"
	SectionRisks      = "risks"
)

type DocSection struct {
	Kind string `json:"kind"`
	// Text or Items; a section with both renders Text then Items.
	Text  string    `json:"text,omitempty"`
	Items []DocItem `json:"items,omitempty"`
}

type DocItem struct {
	// State: plan uses done|doing|todo; hypotheses open|ruledout|confirmed.
	// Empty renders as a plain bullet.
	State string `json:"state,omitempty"`
	Text  string `json:"text"`
}

// Store roots all data-dir paths. Tests point it at a temp dir.
type Store struct {
	DataDir string
}

func New() (*Store, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	return &Store{DataDir: filepath.Join(home, ".local", "share", "pi-observer")}, nil
}

func (s *Store) SessionsDir() string { return filepath.Join(s.DataDir, "sessions") }
func (s *Store) FeedDir() string     { return filepath.Join(s.DataDir, "feed") }

func (s *Store) RegistryPath(sessionID string) string {
	return filepath.Join(s.SessionsDir(), sessionID+".json")
}

func (s *Store) FeedPath(sessionID string) string {
	return filepath.Join(s.FeedDir(), sessionID+".jsonl")
}

func (s *Store) StatePath(sessionID string) string {
	return filepath.Join(s.FeedDir(), sessionID+".state.json")
}

func (s *Store) EnsureDirs() error {
	if err := os.MkdirAll(s.SessionsDir(), 0o755); err != nil {
		return err
	}
	return os.MkdirAll(s.FeedDir(), 0o755)
}

// ListSessions reads every registry doc, derives effective state via the
// pid-reuse-guarded liveness check, resolves parentage, and orders the
// result: top-level sessions sort idle -> working -> exited (idle waits
// on the user, so it surfaces first), most recently updated first within
// each group; subagent sessions nest directly under their parent. Docs
// with an unknown schemaVersion are rejected (skipped), per contract.
func (s *Store) ListSessions() []SessionInfo {
	_ = s.EnsureDirs()
	entries, err := os.ReadDir(s.SessionsDir())
	if err != nil {
		return nil
	}
	var out []SessionInfo
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(s.SessionsDir(), e.Name()))
		if err != nil {
			continue
		}
		var doc RegistryDoc
		if err := json.Unmarshal(raw, &doc); err != nil {
			continue
		}
		if doc.SchemaVersion != SchemaVersion {
			continue
		}
		eff := doc.State
		if doc.State != Exited && !processAlive(&doc) {
			eff = Exited
		}
		out = append(out, SessionInfo{RegistryDoc: doc, EffectiveState: eff})
	}
	rank := func(st SessionState) int {
		switch st {
		case Idle:
			return 0
		case Working:
			return 1
		default:
			return 2
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		ri, rj := rank(out[i].EffectiveState), rank(out[j].EffectiveState)
		if ri != rj {
			return ri < rj
		}
		return out[i].UpdatedAt > out[j].UpdatedAt
	})
	return nestChildren(resolveParents(out))
}

// resolveParents fills ParentID: session A is a subagent of B when
// A.ppid == B.pid (subagents are direct children of the spawning pi;
// tmux is NOT a signal - children inherit the parent's TMUX_PANE).
// When stale docs share a pid, a non-exited claimant wins.
func resolveParents(sessions []SessionInfo) []SessionInfo {
	byPID := map[int]string{}
	for _, s := range sessions { // exited first, alive overwrite
		if s.EffectiveState == Exited {
			byPID[s.PID] = s.SessionID
		}
	}
	for _, s := range sessions {
		if s.EffectiveState != Exited {
			byPID[s.PID] = s.SessionID
		}
	}
	for i := range sessions {
		if pid := sessions[i].PPID; pid != 0 {
			if id, ok := byPID[pid]; ok && id != sessions[i].SessionID {
				sessions[i].ParentID = id
			}
		}
	}
	return sessions
}

// nestChildren reorders a sorted list so each session's children follow
// it immediately (preserving their relative sort order). Children of
// absent parents stay top-level; a parentage cycle (pid reuse) falls
// back to flat order rather than dropping sessions.
func nestChildren(sessions []SessionInfo) []SessionInfo {
	kids := map[string][]SessionInfo{}
	var top []SessionInfo
	ids := map[string]bool{}
	for _, s := range sessions {
		ids[s.SessionID] = true
	}
	for _, s := range sessions {
		if s.ParentID != "" && ids[s.ParentID] {
			kids[s.ParentID] = append(kids[s.ParentID], s)
		} else {
			top = append(top, s)
		}
	}
	out := make([]SessionInfo, 0, len(sessions))
	seen := map[string]bool{}
	var walk func(SessionInfo)
	walk = func(s SessionInfo) {
		if seen[s.SessionID] {
			return
		}
		seen[s.SessionID] = true
		out = append(out, s)
		for _, c := range kids[s.SessionID] {
			walk(c)
		}
	}
	for _, s := range top {
		walk(s)
	}
	for _, s := range sessions { // cycle fallback: never drop a session
		walk(s)
	}
	return out
}

// processAlive is liveness with a pid-reuse guard: kill -0 alone would
// make crashed sessions immortal once the pid is recycled. Confirm
// identity by comparing process start time (derived from `ps -o etime=`)
// against the recorded one. Stubbed in tests.
var processAlive = func(doc *RegistryDoc) bool {
	if err := syscall.Kill(doc.PID, 0); err != nil {
		return false
	}
	out, err := exec.Command("ps", "-o", "etime=", "-p", strconv.Itoa(doc.PID)).Output()
	if err != nil {
		return false
	}
	elapsed, ok := etimeToMs(string(out))
	if !ok {
		return true // cannot verify; assume alive
	}
	started := float64(time.Now().UnixMilli()) - elapsed
	diff := started - doc.PIDStartedAt
	if diff < 0 {
		diff = -diff
	}
	return diff < 30_000
}

var etimeRe = regexp.MustCompile(`^(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+)$`)

// etimeToMs parses ps etime format: [[dd-]hh:]mm:ss
func etimeToMs(etime string) (float64, bool) {
	m := etimeRe.FindStringSubmatch(strings.TrimSpace(etime))
	if m == nil {
		return 0, false
	}
	atoi := func(s string) float64 {
		if s == "" {
			return 0
		}
		n, _ := strconv.Atoi(s)
		return float64(n)
	}
	d, h, min, sec := atoi(m[1]), atoi(m[2]), atoi(m[3]), atoi(m[4])
	return (((d*24+h)*60+min)*60 + sec) * 1000, true
}

// ReadFeed reads a session's feed, tolerating a partially-written
// (non-newline-terminated or corrupt) tail by skipping bad lines.
func (s *Store) ReadFeed(sessionID string) []FeedEntry {
	raw, err := os.ReadFile(s.FeedPath(sessionID))
	if err != nil {
		return nil
	}
	var out []FeedEntry
	for line := range strings.SplitSeq(string(raw), "\n") {
		if strings.TrimSpace(line) == "" {
			continue
		}
		var e FeedEntry
		if err := json.Unmarshal([]byte(line), &e); err != nil {
			continue // partial tail or corruption; skip
		}
		out = append(out, e)
	}
	return out
}

func (s *Store) AppendFeed(sessionID string, entries []FeedEntry) error {
	if len(entries) == 0 {
		return nil
	}
	if err := s.EnsureDirs(); err != nil {
		return err
	}
	var b strings.Builder
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false) // keep feeds byte-compatible with the TS CLI (no \u003c)
	for _, e := range entries {
		if err := enc.Encode(e); err != nil { // Encode appends the JSONL newline
			return err
		}
	}
	f, err := os.OpenFile(s.FeedPath(sessionID), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(b.String())
	return err
}

func (s *Store) ReadState(sessionID string) *DistillerState {
	raw, err := os.ReadFile(s.StatePath(sessionID))
	if err != nil {
		return nil
	}
	var st DistillerState
	if err := json.Unmarshal(raw, &st); err != nil {
		return nil
	}
	return &st
}

// WriteState writes state.json atomically (tmp + rename), per contract.
func (s *Store) WriteState(sessionID string, st DistillerState) error {
	if err := s.EnsureDirs(); err != nil {
		return err
	}
	var buf strings.Builder
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(st); err != nil {
		return err
	}
	raw := []byte(strings.TrimSuffix(buf.String(), "\n"))
	path := s.StatePath(sessionID)
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, raw, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// Watermark implements the exact crash-safe rule from CONTRACT.md.
// state.json legitimately runs AHEAD of the feed (emit-nothing chunks
// advance only state.json); the cached state wins whenever it is at or
// past the feed. The feed wins only when it is ahead - the crash window
// between feed-append and state-write - so lines are never duplicated
// and quiet regions are never re-fed to the LLM.
func (s *Store) Watermark(sessionID string) DistillerState {
	cached := s.ReadState(sessionID)
	feed := s.ReadFeed(sessionID)
	var fromFeed int64
	if len(feed) > 0 {
		fromFeed = feed[len(feed)-1].UpTo
	}
	if cached != nil && cached.UpTo >= fromFeed {
		return *cached
	}
	state := ""
	var doc *SessionDoc
	if cached != nil {
		state = cached.State
		doc = cached.Doc
	}
	return DistillerState{UpTo: fromFeed, State: state, Doc: doc}
}

func (s *Store) ClearFeed(sessionID string) error {
	if err := rmForce(s.FeedPath(sessionID)); err != nil {
		return err
	}
	return rmForce(s.StatePath(sessionID))
}

// GC deletes observer files (never pi's session files) for sessions that
// exited more than maxAgeDays ago. This is the contract's one
// cross-ownership write: delete-only rights over sessions/ docs.
func (s *Store) GC(maxAgeDays int) int {
	cutoff := time.Now().AddDate(0, 0, -maxAgeDays)
	removed := 0
	for _, info := range s.ListSessions() {
		if info.EffectiveState != Exited {
			continue
		}
		// Unparseable updatedAt counts as ancient (matches the TS CLI:
		// NaN never compares above the cutoff), so corrupt docs still
		// get collected instead of living forever.
		if updated, err := time.Parse(time.RFC3339, info.UpdatedAt); err == nil && updated.After(cutoff) {
			continue
		}
		_ = rmForce(s.RegistryPath(info.SessionID))
		_ = s.ClearFeed(info.SessionID)
		removed++
	}
	return removed
}

func rmForce(path string) error {
	err := os.Remove(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	return err
}
