package store

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func tempStore(t *testing.T) *Store {
	t.Helper()
	return &Store{DataDir: t.TempDir()}
}

// --- watermark ---------------------------------------------------------

func TestWatermarkEmpty(t *testing.T) {
	s := tempStore(t)
	wm := s.Watermark("sid")
	if wm.UpTo != 0 || wm.State != "" {
		t.Fatalf("got %+v, want zero", wm)
	}
}

func TestWatermarkFeedOnly(t *testing.T) {
	s := tempStore(t)
	mustAppend(t, s, "sid", []FeedEntry{
		{T: "2026-01-01T00:00:00.000Z", Kind: KindNote, Text: "a", UpTo: 100},
		{T: "2026-01-01T00:01:00.000Z", Kind: KindNote, Text: "b", UpTo: 250},
	})
	wm := s.Watermark("sid")
	if wm.UpTo != 250 || wm.State != "" {
		t.Fatalf("got %+v, want upTo=250 state=\"\"", wm)
	}
}

// The critical case: state.json legitimately runs AHEAD of the feed when
// trailing chunks emit nothing. A watermark derived purely from the feed
// would re-feed that quiet region to the LLM on every pass.
func TestWatermarkStateAheadOfFeed(t *testing.T) {
	s := tempStore(t)
	mustAppend(t, s, "sid", []FeedEntry{
		{T: "2026-01-01T00:00:00.000Z", Kind: KindNote, Text: "a", UpTo: 100},
	})
	if err := s.WriteState("sid", DistillerState{UpTo: 900, State: "quiet region distilled"}); err != nil {
		t.Fatal(err)
	}
	wm := s.Watermark("sid")
	if wm.UpTo != 900 || wm.State != "quiet region distilled" {
		t.Fatalf("got %+v, want cached state to win", wm)
	}
}

// Crash window: feed appended, state write never happened (state behind).
// The feed wins for upTo, but the cached rolling summary is kept.
func TestWatermarkFeedAheadOfState(t *testing.T) {
	s := tempStore(t)
	if err := s.WriteState("sid", DistillerState{UpTo: 100, State: "old summary", Doc: &SessionDoc{Now: "old now", Story: "arc"}}); err != nil {
		t.Fatal(err)
	}
	mustAppend(t, s, "sid", []FeedEntry{
		{T: "2026-01-01T00:00:00.000Z", Kind: KindNote, Text: "a", UpTo: 400},
	})
	wm := s.Watermark("sid")
	if wm.UpTo != 400 || wm.State != "old summary" {
		t.Fatalf("got %+v, want upTo=400 state=\"old summary\"", wm)
	}
	if wm.Doc == nil || wm.Doc.Now != "old now" {
		t.Fatalf("cached doc must survive the feed-wins path: %+v", wm.Doc)
	}
}

func TestStateDocRoundTrip(t *testing.T) {
	s := tempStore(t)
	in := DistillerState{UpTo: 7, State: "now line", Doc: &SessionDoc{
		Now:     "now line",
		Waiting: "needs a decision",
		Sections: []DocSection{
			{Kind: SectionPlan, Items: []DocItem{{State: "done", Text: "a"}, {State: "todo", Text: "b"}}},
			{Kind: "custom", Text: "unknown kind survives round trip"},
		},
		Story: "the arc so far",
	}}
	if err := s.WriteState("sid", in); err != nil {
		t.Fatal(err)
	}
	out := s.ReadState("sid")
	if out == nil || out.Doc == nil {
		t.Fatal("state or doc missing after round trip")
	}
	if out.Doc.Waiting != in.Doc.Waiting || out.Doc.Story != in.Doc.Story ||
		len(out.Doc.Sections) != 2 || out.Doc.Sections[1].Kind != "custom" ||
		out.Doc.Sections[0].Items[1].State != "todo" {
		t.Fatalf("round trip mangled doc: %+v", out.Doc)
	}
}

// --- feed --------------------------------------------------------------

func TestReadFeedToleratesPartialTail(t *testing.T) {
	s := tempStore(t)
	if err := s.EnsureDirs(); err != nil {
		t.Fatal(err)
	}
	raw := `{"t":"2026-01-01T00:00:00.000Z","kind":"prompt","text":"hello","upTo":10}` + "\n" +
		`{"t":"2026-01-01T00:01:00.000Z","kind":"phase","text":"working","upTo":2` // torn write
	if err := os.WriteFile(s.FeedPath("sid"), []byte(raw), 0o644); err != nil {
		t.Fatal(err)
	}
	feed := s.ReadFeed("sid")
	if len(feed) != 1 || feed[0].Text != "hello" {
		t.Fatalf("got %+v, want only the complete line", feed)
	}
}

// Compat: a feed line byte-for-byte as the TS CLI writes it (JSON.stringify
// field order, optional detail present).
func TestReadFeedTSCompat(t *testing.T) {
	s := tempStore(t)
	if err := s.EnsureDirs(); err != nil {
		t.Fatal(err)
	}
	raw := `{"t":"2026-07-04T19:41:58.484Z","kind":"insight","text":"Key decision made","detail":"Chose approach A over B because of C.","upTo":16563}` + "\n"
	if err := os.WriteFile(s.FeedPath("sid"), []byte(raw), 0o644); err != nil {
		t.Fatal(err)
	}
	feed := s.ReadFeed("sid")
	if len(feed) != 1 {
		t.Fatalf("got %d entries, want 1", len(feed))
	}
	e := feed[0]
	if e.Kind != KindInsight || e.Text != "Key decision made" ||
		e.Detail != "Chose approach A over B because of C." || e.UpTo != 16563 {
		t.Fatalf("bad entry: %+v", e)
	}
}

func TestAppendFeedRoundTripOmitsEmptyDetail(t *testing.T) {
	s := tempStore(t)
	mustAppend(t, s, "sid", []FeedEntry{
		{T: "2026-01-01T00:00:00.000Z", Kind: KindNote, Text: "no detail", UpTo: 1},
	})
	raw, err := os.ReadFile(s.FeedPath("sid"))
	if err != nil {
		t.Fatal(err)
	}
	if want := `{"t":"2026-01-01T00:00:00.000Z","kind":"note","text":"no detail","upTo":1}` + "\n"; string(raw) != want {
		t.Fatalf("got %q, want %q", raw, want)
	}
}

// Feeds must stay greppable and byte-compatible with the TS CLI: no
// HTML escaping of <, >, & (JSON.stringify does not escape them).
func TestAppendFeedDoesNotHTMLEscape(t *testing.T) {
	s := tempStore(t)
	mustAppend(t, s, "sid", []FeedEntry{
		{T: "2026-01-01T00:00:00.000Z", Kind: KindNote, Text: "a -> b <c> & `d`", UpTo: 1},
	})
	raw, err := os.ReadFile(s.FeedPath("sid"))
	if err != nil {
		t.Fatal(err)
	}
	if want := `{"t":"2026-01-01T00:00:00.000Z","kind":"note","text":"a -> b <c> & ` + "`d`" + `","upTo":1}` + "\n"; string(raw) != want {
		t.Fatalf("got %q, want %q", raw, want)
	}
}

// --- registry ----------------------------------------------------------

func TestListSessionsRejectsUnknownSchemaVersion(t *testing.T) {
	s := tempStore(t)
	writeDoc(t, s, `{"schemaVersion":2,"sessionId":"future","pid":1,"state":"exited","updatedAt":"2026-01-01T00:00:00.000Z"}`, "future")
	writeDoc(t, s, `{"schemaVersion":1,"sessionId":"ok","pid":1,"state":"exited","updatedAt":"2026-01-01T00:00:00.000Z"}`, "ok")
	got := s.ListSessions()
	if len(got) != 1 || got[0].SessionID != "ok" {
		t.Fatalf("got %+v, want only schemaVersion 1 doc", got)
	}
}

func TestListSessionsSortAndLiveness(t *testing.T) {
	s := tempStore(t)
	restore := stubAlive(map[int]bool{1: true, 2: true, 3: false})
	defer restore()

	writeDoc(t, s, `{"schemaVersion":1,"sessionId":"idle-new","pid":1,"state":"idle","updatedAt":"2026-01-02T00:00:00.000Z"}`, "idle-new")
	writeDoc(t, s, `{"schemaVersion":1,"sessionId":"working","pid":2,"state":"working","updatedAt":"2026-01-01T00:00:00.000Z"}`, "working")
	// claims working but pid is dead -> effective exited
	writeDoc(t, s, `{"schemaVersion":1,"sessionId":"crashed","pid":3,"state":"working","updatedAt":"2026-01-03T00:00:00.000Z"}`, "crashed")
	// tmux-attached working session ranks above headless ones despite
	// being older (headless = usually a subagent)
	writeDoc(t, s, `{"schemaVersion":1,"sessionId":"working-tmux","pid":2,"state":"working","tmux":{"pane":"%1"},"updatedAt":"2025-12-01T00:00:00.000Z"}`, "working-tmux")

	got := s.ListSessions()
	if len(got) != 4 {
		t.Fatalf("got %d sessions", len(got))
	}
	// idle first (waiting on the user), then working, then exited
	wantOrder := []string{"idle-new", "working-tmux", "working", "crashed"}
	for i, id := range wantOrder {
		if got[i].SessionID != id {
			t.Fatalf("position %d: got %s, want %s (full: %+v)", i, got[i].SessionID, id, got)
		}
	}
	if got[3].EffectiveState != Exited {
		t.Fatalf("crashed session: effective state %s, want exited", got[3].EffectiveState)
	}
}

// --- gc ----------------------------------------------------------------

func TestGC(t *testing.T) {
	s := tempStore(t)
	restore := stubAlive(map[int]bool{})
	defer restore()

	old := time.Now().AddDate(0, 0, -30).UTC().Format(time.RFC3339)
	recent := time.Now().UTC().Format(time.RFC3339)
	writeDoc(t, s, `{"schemaVersion":1,"sessionId":"old","pid":9,"state":"exited","updatedAt":"`+old+`"}`, "old")
	writeDoc(t, s, `{"schemaVersion":1,"sessionId":"recent","pid":9,"state":"exited","updatedAt":"`+recent+`"}`, "recent")
	// unparseable updatedAt counts as ancient (contract: never immortal)
	writeDoc(t, s, `{"schemaVersion":1,"sessionId":"corrupt","pid":9,"state":"exited","updatedAt":"garbage"}`, "corrupt")
	mustAppend(t, s, "old", []FeedEntry{{T: old, Kind: KindNote, Text: "x", UpTo: 1}})
	if err := s.WriteState("old", DistillerState{UpTo: 1}); err != nil {
		t.Fatal(err)
	}

	if n := s.GC(14); n != 2 {
		t.Fatalf("gc removed %d, want 2 (old + corrupt)", n)
	}
	if _, err := os.Stat(s.RegistryPath("corrupt")); !os.IsNotExist(err) {
		t.Fatal("corrupt-updatedAt doc not collected")
	}
	for _, p := range []string{s.RegistryPath("old"), s.FeedPath("old"), s.StatePath("old")} {
		if _, err := os.Stat(p); !os.IsNotExist(err) {
			t.Fatalf("%s still exists", p)
		}
	}
	if _, err := os.Stat(s.RegistryPath("recent")); err != nil {
		t.Fatalf("recent doc collected: %v", err)
	}
}

// --- etime -------------------------------------------------------------

func TestEtimeToMs(t *testing.T) {
	cases := []struct {
		in   string
		want float64
		ok   bool
	}{
		{"01:02", 62_000, true},
		{"  10:30:00\n", 37_800_000, true},
		{"2-01:00:00", 176_400_000, true},
		{"garbage", 0, false},
		{"", 0, false},
	}
	for _, c := range cases {
		got, ok := etimeToMs(c.in)
		if got != c.want || ok != c.ok {
			t.Errorf("etimeToMs(%q) = %v,%v want %v,%v", c.in, got, ok, c.want, c.ok)
		}
	}
}

// --- helpers -----------------------------------------------------------

func mustAppend(t *testing.T, s *Store, id string, entries []FeedEntry) {
	t.Helper()
	if err := s.AppendFeed(id, entries); err != nil {
		t.Fatal(err)
	}
}

func writeDoc(t *testing.T, s *Store, raw, id string) {
	t.Helper()
	if err := s.EnsureDirs(); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(s.SessionsDir(), id+".json"), []byte(raw), 0o644); err != nil {
		t.Fatal(err)
	}
}

func stubAlive(alive map[int]bool) (restore func()) {
	orig := processAlive
	processAlive = func(doc *RegistryDoc) bool { return alive[doc.PID] }
	return func() { processAlive = orig }
}
