package text

import "testing"

func TestTruncate(t *testing.T) {
	if got := Truncate("hello", 10); got != "hello" {
		t.Errorf("got %q", got)
	}
	if got := Truncate("hello world", 6); got != "hello…" {
		t.Errorf("got %q", got)
	}
}

func TestCollapse(t *testing.T) {
	if got := Collapse("  a\n\tb   c "); got != "a b c" {
		t.Errorf("got %q", got)
	}
}

func TestBriefArgs(t *testing.T) {
	cases := []struct {
		tool string
		args map[string]any
		want string
	}{
		{"bash", map[string]any{"command": "ls -la"}, "ls -la"},
		{"read", map[string]any{"path": "/tmp/x"}, "/tmp/x"},
		{"grep", map[string]any{"pattern": "foo"}, "foo"},
		{"custom", map[string]any{"query": "bar"}, "bar"},
		{"custom", map[string]any{"n": 42.0}, `{"n":42}`},
		{"bash", nil, ""},
	}
	for _, c := range cases {
		if got := BriefArgs(c.tool, c.args); got != c.want {
			t.Errorf("BriefArgs(%s, %v) = %q, want %q", c.tool, c.args, got, c.want)
		}
	}
}
