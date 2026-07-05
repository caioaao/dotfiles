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
// pid identity check.
type SessionInfo struct {
	RegistryDoc
	EffectiveState SessionState
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
	// State is the distiller's rolling summary, carried across calls.
	State string `json:"state"`
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
// pid-reuse-guarded liveness check, and sorts working -> idle -> exited,
// most recently updated first within each group. Docs with an unknown
// schemaVersion are rejected (skipped), per contract.
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
		case Working:
			return 0
		case Idle:
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
	if cached != nil {
		state = cached.State
	}
	return DistillerState{UpTo: fromFeed, State: state}
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
