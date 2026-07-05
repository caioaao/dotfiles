// Package text holds the small shared text helpers used when building
// feed and registry strings. Semantics ported from the TS implementation
// (lib/registry.ts), except truncation counts runes, not UTF-16 units.
package text

import (
	"encoding/json"
	"regexp"
	"strings"
)

// JS \s is Unicode-aware; Go's is ASCII-only. Include the separators JS
// collapses so feed text matches the TS implementation.
var whitespace = regexp.MustCompile(`[\s\p{Z}\x{2028}\x{2029}\x{FEFF}]+`)

// Truncate cuts s to at most n runes, replacing the tail with an ellipsis.
func Truncate(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n-1]) + "…"
}

// Collapse squeezes all whitespace runs into single spaces and trims.
func Collapse(s string) string {
	return strings.TrimSpace(whitespace.ReplaceAllString(s, " "))
}

// BriefArgs renders a one-line summary of a tool call's arguments.
func BriefArgs(toolName string, args map[string]any) string {
	if args == nil {
		return ""
	}
	first := func(keys ...string) (string, bool) {
		for _, k := range keys {
			if v, ok := args[k].(string); ok && v != "" {
				return v, true
			}
		}
		return "", false
	}
	var s string
	var ok bool
	switch toolName {
	case "bash":
		s, ok = first("command", "cmd")
	case "read", "write", "edit":
		s, ok = first("path", "file_path", "filePath")
	case "grep", "ffgrep", "glob", "fffind", "find":
		s, ok = first("pattern", "path")
	default:
		s, ok = first("path", "pattern", "command", "query", "url", "task", "prompt", "label")
	}
	if !ok {
		if b, err := json.Marshal(args); err == nil {
			s = string(b)
		}
	}
	return Truncate(Collapse(s), 100)
}
