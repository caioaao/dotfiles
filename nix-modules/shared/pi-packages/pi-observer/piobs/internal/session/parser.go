// Package session parses pi's session JSONL files (documented, versioned
// format - see pi's docs/session-format.md). The only package that touches
// pi's format; everything downstream works with ActivityItems.
//
// Reads incrementally from a byte offset. Only newline-terminated lines
// are consumed; the returned upTo never points past an incomplete tail,
// which is what makes the distiller watermark safe against partial writes.
package session

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strings"
	"time"

	"piobs/internal/text"
)

const (
	thinkingBudget = 1400
	textBudget     = 1400
	resultBudget   = 160
)

type ToolUse struct {
	Name        string
	Brief       string
	IsError     bool
	ResultBrief string
}

type ItemType string

const (
	Turn   ItemType = "turn"
	Prompt ItemType = "prompt"
	Marker ItemType = "marker"
)

type MarkerKind string

const (
	MarkerDone       MarkerKind = "done"
	MarkerError      MarkerKind = "error"
	MarkerCompaction MarkerKind = "compaction"
	MarkerBranch     MarkerKind = "branch"
)

// ActivityItem is one unit of session activity. Type discriminates:
// prompt/marker use Text (+Kind for markers); turn uses Thinking, Text,
// Tools, StopReason.
type ActivityItem struct {
	Type       ItemType
	T          string
	Text       string
	Kind       MarkerKind // markers only
	Thinking   string     // turns only
	Tools      []*ToolUse // turns only
	StopReason string     // turns only
	// UpTo is the byte offset just past the last complete session-file
	// line this item covers.
	UpTo int64
}

type ParseResult struct {
	Items []*ActivityItem
	// UpTo is the byte offset after the last complete line consumed.
	UpTo int64
}

// ParseSince parses session-file content from a byte offset onward.
func ParseSince(sessionFile string, offset int64) ParseResult {
	buf, err := os.ReadFile(sessionFile)
	if err != nil || offset >= int64(len(buf)) {
		return ParseResult{UpTo: offset}
	}

	p := &parser{openTools: map[string]openTool{}}

	pos := offset
	for {
		nl := bytes.IndexByte(buf[pos:], '\n')
		if nl == -1 {
			break
		}
		lineEnd := pos + int64(nl) + 1
		line := bytes.TrimSpace(buf[pos:lineEnd])
		pos = lineEnd
		if len(line) == 0 {
			continue
		}
		p.consumeLine(line, lineEnd)
	}

	return ParseResult{Items: p.items, UpTo: pos}
}

// openTool links a pending toolCall to its owning turn, so results can
// attach and extend the turn's byte coverage (keeps a turn and its
// results in the same distillation chunk).
type openTool struct {
	tool *ToolUse
	turn *ActivityItem
}

type parser struct {
	items     []*ActivityItem
	openTools map[string]openTool
}

func (p *parser) consumeLine(line []byte, lineEnd int64) {
	var entry struct {
		Type      string          `json:"type"`
		Timestamp string          `json:"timestamp"`
		Message   json.RawMessage `json:"message"`
		Summary   string          `json:"summary"`
	}
	if err := json.Unmarshal(line, &entry); err != nil {
		return
	}

	t := entry.Timestamp
	if t == "" {
		t = time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
	}

	switch entry.Type {
	case "message":
		p.consumeMessage(entry.Message, t, lineEnd)
	case "compaction":
		p.items = append(p.items, &ActivityItem{Type: Marker, T: t, Kind: MarkerCompaction, Text: "Compacted context", UpTo: lineEnd})
	case "branch_summary":
		p.items = append(p.items, &ActivityItem{
			Type: Marker, T: t, Kind: MarkerBranch,
			Text: "Switched branch. Abandoned path: " + text.Truncate(text.Collapse(entry.Summary), 300),
			UpTo: lineEnd,
		})
	default:
		// session header, labels, model changes, custom entries:
		// not feed material
	}
}

type contentBlock struct {
	Type      string         `json:"type"`
	Text      string         `json:"text"`
	Thinking  string         `json:"thinking"`
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Arguments map[string]any `json:"arguments"`
}

func (p *parser) consumeMessage(raw json.RawMessage, t string, lineEnd int64) {
	var msg struct {
		Role         string          `json:"role"`
		Content      json.RawMessage `json:"content"`
		Command      string          `json:"command"`
		StopReason   string          `json:"stopReason"`
		ErrorMessage string          `json:"errorMessage"`
		ToolCallID   string          `json:"toolCallId"`
		IsError      bool            `json:"isError"`
	}
	if err := json.Unmarshal(raw, &msg); err != nil {
		return
	}

	switch msg.Role {
	case "user":
		if txt := text.Collapse(extractText(msg.Content)); txt != "" {
			p.items = append(p.items, &ActivityItem{Type: Prompt, T: t, Text: text.Truncate(classifyPrompt(txt), 300), UpTo: lineEnd})
		}
	case "bashExecution":
		p.items = append(p.items, &ActivityItem{
			Type: Prompt, T: t,
			Text: text.Truncate("(user ran) $ "+text.Collapse(msg.Command), 200),
			UpTo: lineEnd,
		})
	case "assistant":
		var blocks []contentBlock
		_ = json.Unmarshal(msg.Content, &blocks)
		var thinkingParts, textParts []string
		for _, b := range blocks {
			switch b.Type {
			case "thinking":
				thinkingParts = append(thinkingParts, b.Thinking)
			case "text":
				textParts = append(textParts, b.Text)
			}
		}
		txt := text.Collapse(strings.Join(textParts, " "))
		turn := &ActivityItem{
			Type:       Turn,
			T:          t,
			Thinking:   text.Truncate(text.Collapse(strings.Join(thinkingParts, " ")), thinkingBudget),
			Text:       text.Truncate(txt, textBudget),
			StopReason: msg.StopReason,
			UpTo:       lineEnd,
		}
		for _, b := range blocks {
			if b.Type != "toolCall" {
				continue
			}
			tool := &ToolUse{Name: b.Name, Brief: text.BriefArgs(b.Name, b.Arguments)}
			turn.Tools = append(turn.Tools, tool)
			if b.ID != "" {
				p.openTools[b.ID] = openTool{tool, turn}
			}
		}
		if turn.Thinking != "" || turn.Text != "" || len(turn.Tools) > 0 {
			p.items = append(p.items, turn)
		}

		switch {
		case msg.StopReason == "error" || msg.StopReason == "aborted":
			errText := "Run aborted"
			if msg.StopReason == "error" {
				em := msg.ErrorMessage
				if em == "" {
					em = "unknown error"
				}
				errText = "Run failed: " + text.Truncate(text.Collapse(em), 200)
			}
			p.items = append(p.items, &ActivityItem{Type: Marker, T: t, Kind: MarkerError, Text: errText, UpTo: lineEnd})
		case msg.StopReason == "stop" && txt != "":
			// End of an agent run. The final answer often opens with prose
			// and degenerates into headings/tables that collapse into noise
			// on one line - keep the first prose paragraph only.
			done := text.Collapse(firstProseParagraph(strings.Join(textParts, "\n\n")))
			if done == "" {
				done = txt
			}
			p.items = append(p.items, &ActivityItem{Type: Marker, T: t, Kind: MarkerDone, Text: text.Truncate(done, 500), UpTo: lineEnd})
		}
	case "toolResult":
		open, ok := p.openTools[msg.ToolCallID]
		if msg.ToolCallID == "" || !ok {
			return
		}
		open.tool.IsError = msg.IsError
		if brief := text.Collapse(extractText(msg.Content)); brief != "" {
			open.tool.ResultBrief = text.Truncate(brief, resultBudget)
		}
		if lineEnd > open.turn.UpTo {
			open.turn.UpTo = lineEnd
		}
		delete(p.openTools, msg.ToolCallID)
	}
}

var skillRe = regexp.MustCompile(`^<skill\s+name="([^"]+)"`)

// classifyPrompt collapses mechanical prompt payloads into short labels.
// Skill injections arrive as the full SKILL.md wrapped in a <skill> tag;
// the human only cares that a skill was loaded, not its body.
func classifyPrompt(txt string) string {
	if m := skillRe.FindStringSubmatch(txt); m != nil {
		return "(loaded skill: " + m[1] + ")"
	}
	return txt
}

// firstProseParagraph returns the first paragraph that is not a heading,
// table, rule, or code fence. Empty string when nothing qualifies.
func firstProseParagraph(s string) string {
	for para := range strings.SplitSeq(s, "\n\n") {
		p := strings.TrimSpace(para)
		switch {
		case p == "":
		case strings.HasPrefix(p, "#"), strings.HasPrefix(p, "|"),
			strings.HasPrefix(p, "---"), strings.HasPrefix(p, "```"):
		default:
			return p
		}
	}
	return ""
}

// extractText pulls the plain text out of a content field that is either
// a string or an array of typed blocks.
func extractText(content json.RawMessage) string {
	if len(content) == 0 {
		return ""
	}
	var s string
	if err := json.Unmarshal(content, &s); err == nil {
		return s
	}
	var blocks []contentBlock
	if err := json.Unmarshal(content, &blocks); err != nil {
		return ""
	}
	var parts []string
	for _, b := range blocks {
		if b.Type == "text" && b.Text != "" {
			parts = append(parts, b.Text)
		}
	}
	return strings.Join(parts, " ")
}

// RenderItems produces the compact plain-text rendering of activity items
// used for the distiller prompt and the raw view.
func RenderItems(items []*ActivityItem) string {
	var lines []string
	for _, item := range items {
		hm := hhmm(item.T)
		switch item.Type {
		case Prompt:
			lines = append(lines, fmt.Sprintf("[%s] USER: %s", hm, item.Text))
		case Marker:
			lines = append(lines, fmt.Sprintf("[%s] %s: %s", hm, strings.ToUpper(string(item.Kind)), item.Text))
		default:
			lines = append(lines, fmt.Sprintf("[%s] TURN:", hm))
			if item.Thinking != "" {
				lines = append(lines, "  reasoning: "+item.Thinking)
			}
			if item.Text != "" {
				lines = append(lines, "  said: "+item.Text)
			}
			for _, tool := range item.Tools {
				res := ""
				switch {
				case tool.IsError:
					res = " -> ERROR: " + tool.ResultBrief
				case tool.ResultBrief != "":
					res = " -> " + tool.ResultBrief
				}
				lines = append(lines, fmt.Sprintf("  tool: %s(%s)%s", tool.Name, tool.Brief, res))
			}
		}
	}
	return strings.Join(lines, "\n")
}

// hhmm extracts HH:MM from an ISO timestamp (same slice the TS code took).
func hhmm(iso string) string {
	if len(iso) >= 16 {
		return iso[11:16]
	}
	return iso
}
