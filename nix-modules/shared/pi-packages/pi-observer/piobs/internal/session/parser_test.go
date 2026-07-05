package session

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// writeLines writes newline-terminated lines and returns the cumulative
// byte offset after each line, so tests can assert exact upTo values.
func writeLines(t *testing.T, lines []string) (path string, offsets []int64) {
	t.Helper()
	path = filepath.Join(t.TempDir(), "session.jsonl")
	var b strings.Builder
	for _, l := range lines {
		b.WriteString(l)
		b.WriteString("\n")
		offsets = append(offsets, int64(b.Len()))
	}
	if err := os.WriteFile(path, []byte(b.String()), 0o644); err != nil {
		t.Fatal(err)
	}
	return path, offsets
}

const ts = "2026-01-01T12:34:56.000Z"

func TestParseFullSession(t *testing.T) {
	lines := []string{
		`{"type":"session","version":3,"id":"uuid","timestamp":"` + ts + `","cwd":"/tmp"}`,
		`{"type":"message","id":"a1","parentId":null,"timestamp":"` + ts + `","message":{"role":"user","content":"please fix the bug"}}`,
		`{"type":"message","id":"a2","parentId":"a1","timestamp":"` + ts + `","message":{"role":"assistant","content":[{"type":"thinking","thinking":"look at   the file"},{"type":"toolCall","id":"call_1","name":"bash","arguments":{"command":"ls -la"}}],"stopReason":"toolUse"}}`,
		`{"type":"message","id":"a3","parentId":"a2","timestamp":"` + ts + `","message":{"role":"toolResult","toolCallId":"call_1","toolName":"bash","content":[{"type":"text","text":"file1\nfile2"}],"isError":false}}`,
		`{"type":"message","id":"a4","parentId":"a3","timestamp":"` + ts + `","message":{"role":"assistant","content":[{"type":"text","text":"All done."}],"stopReason":"stop"}}`,
		`{"type":"message","id":"a5","parentId":"a4","timestamp":"` + ts + `","message":{"role":"bashExecution","command":"git   status","output":"","exitCode":0}}`,
		`{"type":"compaction","id":"a6","parentId":"a5","timestamp":"` + ts + `","summary":"long ago"}`,
		`{"type":"branch_summary","id":"a7","parentId":"a6","timestamp":"` + ts + `","fromId":"a2","summary":"tried  approach A"}`,
		`{"type":"message","id":"a8","parentId":"a7","timestamp":"` + ts + `","message":{"role":"assistant","content":[],"stopReason":"aborted"}}`,
		`{"type":"message","id":"a9","parentId":"a8","timestamp":"` + ts + `","message":{"role":"assistant","content":[{"type":"text","text":"partial"}],"stopReason":"error","errorMessage":"rate  limited"}}`,
		`{"type":"model_change","id":"aa","parentId":"a9","timestamp":"` + ts + `","provider":"openai","modelId":"gpt-x"}`,
	}
	path, off := writeLines(t, lines)

	res := ParseSince(path, 0)
	if res.UpTo != off[len(off)-1] {
		t.Fatalf("upTo = %d, want %d", res.UpTo, off[len(off)-1])
	}

	type want struct {
		typ  ItemType
		kind MarkerKind
		text string
		upTo int64
	}
	wants := []want{
		{Prompt, "", "please fix the bug", off[1]},
		// turn's upTo extended to its toolResult line
		{Turn, "", "", off[3]},
		{Turn, "", "All done.", off[4]},
		{Marker, MarkerDone, "All done.", off[4]},
		{Prompt, "", "(user ran) $ git status", off[5]},
		{Marker, MarkerCompaction, "Compacted context", off[6]},
		{Marker, MarkerBranch, "Switched branch. Abandoned path: tried approach A", off[7]},
		{Marker, MarkerError, "Run aborted", off[8]},
		{Turn, "", "partial", off[9]},
		{Marker, MarkerError, "Run failed: rate limited", off[9]},
	}
	if len(res.Items) != len(wants) {
		t.Fatalf("got %d items, want %d:\n%s", len(res.Items), len(wants), RenderItems(res.Items))
	}
	for i, w := range wants {
		it := res.Items[i]
		if it.Type != w.typ || it.Kind != w.kind || it.UpTo != w.upTo {
			t.Errorf("item %d: got {%s %s upTo=%d}, want {%s %s upTo=%d}", i, it.Type, it.Kind, it.UpTo, w.typ, w.kind, w.upTo)
		}
		if w.text != "" && it.Text != w.text {
			t.Errorf("item %d text: got %q, want %q", i, it.Text, w.text)
		}
	}

	// tool call details
	turn := res.Items[1]
	if len(turn.Tools) != 1 {
		t.Fatalf("turn tools: %+v", turn.Tools)
	}
	tool := turn.Tools[0]
	if tool.Name != "bash" || tool.Brief != "ls -la" || tool.IsError || tool.ResultBrief != "file1 file2" {
		t.Fatalf("tool: %+v", tool)
	}
	if turn.Thinking != "look at the file" {
		t.Fatalf("thinking: %q", turn.Thinking)
	}
}

func TestParseSinceIncrementalAndPartialTail(t *testing.T) {
	lines := []string{
		`{"type":"message","id":"a1","parentId":null,"timestamp":"` + ts + `","message":{"role":"user","content":"first"}}`,
		`{"type":"message","id":"a2","parentId":"a1","timestamp":"` + ts + `","message":{"role":"user","content":"second"}}`,
	}
	path, off := writeLines(t, lines)

	// incremental read from the first offset only sees the second prompt
	res := ParseSince(path, off[0])
	if len(res.Items) != 1 || res.Items[0].Text != "second" || res.UpTo != off[1] {
		t.Fatalf("incremental: %+v upTo=%d", res.Items, res.UpTo)
	}

	// append a torn line (no trailing newline): must not be consumed
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.WriteString(`{"type":"message","id":"a3","parentId":"a2","timestamp":"` + ts + `","message":{"role":"user","con`); err != nil {
		t.Fatal(err)
	}
	f.Close()

	res = ParseSince(path, off[1])
	if len(res.Items) != 0 || res.UpTo != off[1] {
		t.Fatalf("partial tail consumed: %+v upTo=%d want %d", res.Items, res.UpTo, off[1])
	}

	// offset past EOF is returned untouched
	res = ParseSince(path, 1<<30)
	if res.UpTo != 1<<30 || len(res.Items) != 0 {
		t.Fatalf("past-EOF: %+v", res)
	}
}

func TestParseTruncatesBudgets(t *testing.T) {
	long := strings.Repeat("x", 2000)
	lines := []string{
		`{"type":"message","id":"a1","parentId":null,"timestamp":"` + ts + `","message":{"role":"assistant","content":[{"type":"thinking","thinking":"` + long + `"},{"type":"text","text":"` + long + `"}],"stopReason":"stop"}}`,
	}
	path, _ := writeLines(t, lines)
	res := ParseSince(path, 0)
	if len(res.Items) != 2 { // turn + done marker
		t.Fatalf("items: %d", len(res.Items))
	}
	turn := res.Items[0]
	if n := len([]rune(turn.Thinking)); n != 1400 {
		t.Errorf("thinking budget: %d runes", n)
	}
	if n := len([]rune(turn.Text)); n != 1400 {
		t.Errorf("text budget: %d runes", n)
	}
	if n := len([]rune(res.Items[1].Text)); n != 500 {
		t.Errorf("done budget: %d runes", n)
	}
}

func TestClassifyPromptSkillInjection(t *testing.T) {
	skill := `<skill name=\"present\" location=\"/home/u/.pi/skills/present/SKILL.md\"> # Present Turn a source doc into HTML`
	lines := []string{
		`{"type":"message","id":"a1","parentId":null,"timestamp":"` + ts + `","message":{"role":"user","content":"` + skill + `"}}`,
	}
	path, _ := writeLines(t, lines)
	res := ParseSince(path, 0)
	if len(res.Items) != 1 || res.Items[0].Text != "(loaded skill: present)" {
		t.Fatalf("got %+v", res.Items)
	}
}

func TestDoneMarkerKeepsFirstProseParagraph(t *testing.T) {
	body := `## Heading\n\nAll wired up and tested.\n\n| a | b |\n|---|---|\n| 1 | 2 |`
	lines := []string{
		`{"type":"message","id":"a1","parentId":null,"timestamp":"` + ts + `","message":{"role":"assistant","content":[{"type":"text","text":"` + body + `"}],"stopReason":"stop"}}`,
	}
	path, _ := writeLines(t, lines)
	res := ParseSince(path, 0)
	if len(res.Items) != 2 {
		t.Fatalf("items: %+v", res.Items)
	}
	done := res.Items[1]
	if done.Kind != MarkerDone || done.Text != "All wired up and tested." {
		t.Fatalf("done marker: %+v", done)
	}
}

func TestParseSkipsGarbageLines(t *testing.T) {
	lines := []string{
		`not json at all`,
		`{"type":"message","id":"a1","parentId":null,"timestamp":"` + ts + `","message":{"role":"user","content":"ok"}}`,
	}
	path, off := writeLines(t, lines)
	res := ParseSince(path, 0)
	if len(res.Items) != 1 || res.Items[0].Text != "ok" || res.UpTo != off[1] {
		t.Fatalf("got %+v upTo=%d", res.Items, res.UpTo)
	}
}

func TestRenderItems(t *testing.T) {
	items := []*ActivityItem{
		{Type: Prompt, T: ts, Text: "do it"},
		{Type: Turn, T: ts, Thinking: "hmm", Text: "on it", Tools: []*ToolUse{
			{Name: "bash", Brief: "make", ResultBrief: "ok"},
			{Name: "read", Brief: "main.go", IsError: true, ResultBrief: "no such file"},
		}},
		{Type: Marker, T: ts, Kind: MarkerDone, Text: "finished"},
	}
	got := RenderItems(items)
	want := strings.Join([]string{
		"[12:34] USER: do it",
		"[12:34] TURN:",
		"  reasoning: hmm",
		"  said: on it",
		"  tool: bash(make) -> ok",
		"  tool: read(main.go) -> ERROR: no such file",
		"[12:34] DONE: finished",
	}, "\n")
	if got != want {
		t.Fatalf("got:\n%s\nwant:\n%s", got, want)
	}
}
