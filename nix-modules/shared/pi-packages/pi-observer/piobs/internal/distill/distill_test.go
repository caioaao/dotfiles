package distill

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"piobs/internal/store"
)

const ts = "2026-01-01T12:00:00.000Z"

type fakeLLM struct {
	responses []string // popped per call
	calls     []string // prompts received
	err       error
}

func (f *fakeLLM) complete(_ context.Context, _, prompt string) (string, error) {
	f.calls = append(f.calls, prompt)
	if f.err != nil {
		return "", f.err
	}
	if len(f.responses) == 0 {
		return `{"lines":[],"doc":{"now":"s","story":""}}`, nil
	}
	r := f.responses[0]
	f.responses = f.responses[1:]
	return r, nil
}

func setup(t *testing.T, lines []string) (*store.Store, store.SessionInfo) {
	t.Helper()
	st := &store.Store{DataDir: t.TempDir()}
	path := filepath.Join(t.TempDir(), "session.jsonl")
	if err := os.WriteFile(path, []byte(strings.Join(lines, "\n")+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	doc := store.SessionInfo{RegistryDoc: store.RegistryDoc{SessionID: "sid", SessionFile: path}}
	return st, doc
}

func userLine(text string) string {
	return `{"type":"message","timestamp":"` + ts + `","message":{"role":"user","content":"` + text + `"}}`
}

func turnLine(thinking string) string {
	return `{"type":"message","timestamp":"` + ts + `","message":{"role":"assistant","content":[{"type":"thinking","thinking":"` + thinking + `"}],"stopReason":"toolUse"}}`
}

func doneLine(text string) string {
	return `{"type":"message","timestamp":"` + ts + `","message":{"role":"assistant","content":[{"type":"text","text":"` + text + `"}],"stopReason":"stop"}}`
}

func TestMechanicalBypassesLLM(t *testing.T) {
	st, doc := setup(t, []string{userLine("fix bug")})
	llm := &fakeLLM{}
	d := &Distiller{st: st, llm: llm}
	n, err := d.Session(context.Background(), doc, nil)
	if err != nil || n != 1 {
		t.Fatalf("n=%d err=%v", n, err)
	}
	if len(llm.calls) != 0 {
		t.Fatalf("LLM called for mechanical-only session")
	}
	feed := st.ReadFeed("sid")
	if len(feed) != 1 || feed[0].Kind != store.KindPrompt || feed[0].Text != "fix bug" {
		t.Fatalf("feed: %+v", feed)
	}
	wm := st.Watermark("sid")
	if wm.UpTo <= feed[0].UpTo-1 {
		t.Fatalf("state not advanced: %+v", wm)
	}
}

func TestChunkingAndOrdering(t *testing.T) {
	// 17 turns then a done: expect 2 LLM calls (15 + 2) flushed before
	// the mechanical done entry.
	var lines []string
	lines = append(lines, userLine("go"))
	for i := 0; i < 16; i++ {
		lines = append(lines, turnLine(fmt.Sprintf("step %d", i)))
	}
	lines = append(lines, doneLine("finished"))
	st, doc := setup(t, lines)

	llm := &fakeLLM{responses: []string{
		`{"lines":[{"kind":"phase","text":"chunk one"}],"doc":{"now":"s1","story":"st1"}}`,
		`{"lines":[{"kind":"insight","text":"chunk two"}],"doc":{"now":"s2","story":"st2"}}`,
	}}
	d := &Distiller{st: st, llm: llm}
	n, err := d.Session(context.Background(), doc, nil)
	if err != nil {
		t.Fatal(err)
	}
	// prompt + 2 llm lines + turn(done line has text -> also a turn) is in
	// second chunk + done marker
	if len(llm.calls) != 2 {
		t.Fatalf("llm calls: %d", len(llm.calls))
	}
	feed := st.ReadFeed("sid")
	var kinds []string
	for _, e := range feed {
		kinds = append(kinds, string(e.Kind))
	}
	want := []string{"prompt", "phase", "insight", "done"}
	if strings.Join(kinds, ",") != strings.Join(want, ",") {
		t.Fatalf("feed order: %v, want %v", kinds, want)
	}
	if n != len(feed) {
		t.Fatalf("n=%d, feed=%d", n, len(feed))
	}
	// second call's DOC must carry the first call's rewritten doc
	if !strings.Contains(llm.calls[1], `"now":"s1"`) || !strings.Contains(llm.calls[1], `"story":"st1"`) {
		t.Fatalf("rolling doc not threaded:\n%s", llm.calls[1])
	}
	// feed tail of second call includes first chunk's line
	if !strings.Contains(llm.calls[1], "chunk one") {
		t.Fatalf("feed tail not threaded:\n%s", llm.calls[1])
	}
}

func TestEmitNothingAdvancesStateOnly(t *testing.T) {
	st, doc := setup(t, []string{turnLine("quiet work")})
	llm := &fakeLLM{responses: []string{`{"lines":[],"doc":{"now":"remembered","story":"the story"}}`}}
	d := &Distiller{st: st, llm: llm}
	n, err := d.Session(context.Background(), doc, nil)
	if err != nil || n != 0 {
		t.Fatalf("n=%d err=%v", n, err)
	}
	if len(st.ReadFeed("sid")) != 0 {
		t.Fatal("feed should be empty")
	}
	wm := st.Watermark("sid")
	if wm.UpTo == 0 || wm.State != "remembered" {
		t.Fatalf("watermark: %+v", wm)
	}
	if wm.Doc == nil || wm.Doc.Story != "the story" {
		t.Fatalf("doc not persisted: %+v", wm.Doc)
	}
	// second pass: nothing new, LLM not called again (the naive
	// feed-derived watermark would re-feed this quiet region)
	n, err = d.Session(context.Background(), doc, nil)
	if err != nil || n != 0 || len(llm.calls) != 1 {
		t.Fatalf("re-fed quiet region: n=%d err=%v calls=%d", n, err, len(llm.calls))
	}
}

func TestLLMErrorKeepsWatermarkConsistent(t *testing.T) {
	var lines []string
	for i := 0; i < 16; i++ {
		lines = append(lines, turnLine(fmt.Sprintf("step %d", i)))
	}
	st, doc := setup(t, lines)
	llm := &fakeLLM{
		responses: []string{`{"lines":[{"kind":"note","text":"first"}],"doc":{"now":"s1","story":""}}`},
	}
	d := &Distiller{st: st, llm: llm}
	// first chunk ok, then fail the second
	llm.err = nil
	n, err := d.Session(context.Background(), doc, func(e store.FeedEntry) {
		llm.err = fmt.Errorf("boom") // fail after first response consumed
	})
	if err == nil || n != 1 {
		t.Fatalf("n=%d err=%v", n, err)
	}
	// rerun with a working LLM continues from the first chunk's watermark
	llm.err = nil
	llm.responses = []string{`{"lines":[{"kind":"note","text":"second"}],"doc":{"now":"s2","story":""}}`}
	n, err = d.Session(context.Background(), doc, nil)
	if err != nil || n != 1 {
		t.Fatalf("rerun: n=%d err=%v", n, err)
	}
	feed := st.ReadFeed("sid")
	if len(feed) != 2 || feed[0].Text != "first" || feed[1].Text != "second" {
		t.Fatalf("feed after recovery: %+v", feed)
	}
}

// A cancelled distill must stop appending and advancing state between
// chunks: the TUI clears the feed for redistill right after cancelling.
func TestCancelStopsWritesBetweenChunks(t *testing.T) {
	var lines []string
	for i := 0; i < 16; i++ {
		lines = append(lines, turnLine(fmt.Sprintf("step %d", i)))
	}
	st, doc := setup(t, lines)
	ctx, cancel := context.WithCancel(context.Background())
	llm := &fakeLLM{responses: []string{`{"lines":[{"kind":"note","text":"first"}],"doc":{"now":"s1","story":""}}`}}
	d := &Distiller{st: st, llm: llm}
	n, err := d.Session(ctx, doc, func(store.FeedEntry) { cancel() })
	if err == nil || n != 1 {
		t.Fatalf("n=%d err=%v, want cancellation after first chunk", n, err)
	}
	if len(llm.calls) != 1 {
		t.Fatalf("second chunk still hit the LLM after cancel")
	}
}

func TestParseResponse(t *testing.T) {
	prev := &store.SessionDoc{Now: "old", Story: "old story"}

	entries, doc := parseResponse("```json\n{\"lines\":[{\"kind\":\"bogus\",\"text\":\" hi \",\"detail\":\" why \"}],\"doc\":{\"now\":\"new\",\"story\":\"s\"}}\n```", prev, ts)
	if len(entries) != 1 {
		t.Fatalf("entries: %+v", entries)
	}
	e := entries[0]
	if e.Kind != store.KindNote || e.Text != "hi" || e.Detail != "why" || e.T != ts {
		t.Fatalf("entry: %+v", e)
	}
	if doc == nil || doc.Now != "new" {
		t.Fatalf("doc: %+v", doc)
	}

	// garbage keeps the previous doc
	entries, doc = parseResponse("total garbage", prev, ts)
	if entries != nil || doc != prev {
		t.Fatalf("garbage handling: %+v %+v", entries, doc)
	}

	// missing doc keeps the previous doc
	entries, doc = parseResponse(`{"lines":[{"kind":"phase","text":""}]}`, prev, ts)
	if len(entries) != 0 || doc != prev {
		t.Fatalf("empty-text/missing-doc: %+v %+v", entries, doc)
	}

	// blank "now" keeps the previous doc
	_, doc = parseResponse(`{"lines":[],"doc":{"now":"  ","story":"x"}}`, prev, ts)
	if doc != prev {
		t.Fatalf("blank now must keep previous doc: %+v", doc)
	}
}

func TestSanitizeDoc(t *testing.T) {
	long := strings.Repeat("x", 5000)
	var items []store.DocItem
	for i := 0; i < 20; i++ {
		items = append(items, store.DocItem{State: "todo", Text: "item"})
	}
	d := sanitizeDoc(&store.SessionDoc{
		Title: long,
		Now:   long,
		Story: long,
		Sections: []store.DocSection{
			{Kind: "plan", Items: items},
			{Kind: "", Text: "kindless is dropped"},
			{Kind: "empty-is-dropped"},
			{Kind: "custom", Text: "unknown kinds survive"},
		},
	})
	if n := len([]rune(d.Title)); n != docTitleBudget {
		t.Errorf("title budget: %d", n)
	}
	if n := len([]rune(d.Now)); n != docNowBudget {
		t.Errorf("now budget: %d", n)
	}
	if n := len([]rune(d.Story)); n != docStoryBudget {
		t.Errorf("story budget: %d", n)
	}
	if len(d.Sections) != 2 || d.Sections[0].Kind != "plan" || d.Sections[1].Kind != "custom" {
		t.Fatalf("sections: %+v", d.Sections)
	}
	if len(d.Sections[0].Items) != docMaxItems {
		t.Errorf("items: %d", len(d.Sections[0].Items))
	}
}

func TestUnsupportedProvider(t *testing.T) {
	if _, err := New(&store.Store{DataDir: t.TempDir()}, Config{Provider: "openai"}); err == nil {
		t.Fatal("want loud error for non-anthropic provider")
	}
}
