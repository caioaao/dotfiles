package tui

import (
	"image/color"
	"strings"

	"charm.land/glamour/v2"
	"charm.land/lipgloss/v2"

	"piobs/internal/store"
	"piobs/internal/text"
)

// kindStyle describes how one feed kind renders: badge glyph, badge
// color, and how the text body is painted.
type kindStyle struct {
	badge string
	color color.Color
	// paintText: color the whole text line with color (phases get bold)
	paintText bool
	dimText   bool
}

var kindStyles = map[store.FeedKind]kindStyle{
	store.KindPhase:     {badge: "▶", color: lipgloss.Color("45"), paintText: true},
	store.KindInsight:   {badge: "✦", color: lipgloss.Color("213")},
	store.KindNote:      {badge: "·", color: lipgloss.Color("245"), dimText: true},
	store.KindBacktrack: {badge: "↩", color: lipgloss.Color("220"), paintText: true},
	store.KindDone:      {badge: "✔", color: lipgloss.Color("82"), paintText: true},
	store.KindError:     {badge: "✖", color: lipgloss.Color("196"), paintText: true},
	store.KindPrompt:    {badge: "❯", color: lipgloss.Color("231")},
}

// feedView renders feed entries into terminal lines, caching the result.
// Glamour renders are not free: only appended entries are re-rendered,
// keyed on (sessionId, width, showDetails, entryCount).
type feedView struct {
	sessionID   string
	width       int
	showDetails bool
	count       int
	lines       []string
	renderer    *glamour.TermRenderer
}

func (f *feedView) invalidate() { f.count = 0; f.lines = nil }

// setWidth rebuilds the glamour renderer for the new wrap width.
// Mandatory on every width change or markdown wrapping breaks.
func (f *feedView) setWidth(w int) {
	if w == f.width && f.renderer != nil {
		return
	}
	f.width = w
	f.invalidate()
	// Fixed style, no auto-detection: deterministic output, same over
	// ssh/tmux (glamour v2 is pure by design).
	r, err := glamour.NewTermRenderer(
		glamour.WithStandardStyle("dark"),
		glamour.WithWordWrap(max(20, w-6)),
	)
	if err == nil {
		f.renderer = r
	}
}

// render returns the terminal lines for the given feed, reusing cached
// lines for the unchanged prefix.
func (f *feedView) render(sessionID string, entries []store.FeedEntry, showDetails bool) []string {
	if sessionID != f.sessionID || showDetails != f.showDetails || len(entries) < f.count {
		f.sessionID = sessionID
		f.showDetails = showDetails
		f.invalidate()
	}
	for _, e := range entries[f.count:] {
		f.lines = append(f.lines, f.renderEntry(e)...)
	}
	f.count = len(entries)
	return f.lines
}

func (f *feedView) renderEntry(e store.FeedEntry) []string {
	style, ok := kindStyles[e.Kind]
	if !ok {
		style = kindStyles[store.KindNote] // unknown kinds render as note, per contract
	}
	timeStr := dimStyle.Render(hhmm(e.T))
	badge := lipgloss.NewStyle().Foreground(style.color).Render(style.badge)
	textLines := wrap(text.Collapse(e.Text), f.width-10)

	var out []string

	// Prompts are turn boundaries: rule + blank line chunk the feed
	// visually.
	if e.Kind == store.KindPrompt {
		out = append(out, "", dimStyle.Render(" "+strings.Repeat("┄", max(0, f.width-2))))
		bold := lipgloss.NewStyle().Bold(true)
		out = append(out, " "+timeStr+" "+badge+" "+bold.Render(first(textLines)))
		for _, cont := range rest(textLines) {
			out = append(out, "         "+bold.Render(cont))
		}
		return out
	}

	// Done bodies go through glamour: the agent's final answer is one of
	// the two spots where the distiller is allowed markdown.
	if e.Kind == store.KindDone {
		hdr := lipgloss.NewStyle().Foreground(style.color).Bold(true).Render("done")
		out = append(out, "", " "+timeStr+" "+badge+" "+hdr)
		out = append(out, f.markdown(e.Text, "   ")...)
		return out
	}

	// Phases open a new chunk: breathing room above.
	if e.Kind == store.KindPhase {
		out = append(out, "")
	}

	paint := lipgloss.NewStyle()
	switch {
	case style.paintText:
		paint = paint.Foreground(style.color)
		if e.Kind == store.KindPhase {
			paint = paint.Bold(true)
		}
	case style.dimText:
		paint = paint.Faint(true)
	}

	out = append(out, " "+timeStr+" "+badge+" "+paint.Render(first(textLines)))
	for _, cont := range rest(textLines) {
		out = append(out, "         "+paint.Render(cont))
	}

	// Details are the other markdown spot; glamour-rendered when shown.
	if f.showDetails && e.Detail != "" {
		out = append(out, f.markdown(e.Detail, "     ")...)
	}
	return out
}

// markdown renders a snippet through glamour and indents it. Falls back
// to plain wrapped text when the renderer is unavailable.
func (f *feedView) markdown(md, indent string) []string {
	if f.renderer == nil {
		var out []string
		for _, l := range wrap(md, f.width-12) {
			out = append(out, indent+dimStyle.Render(l))
		}
		return out
	}
	rendered, err := f.renderer.Render(md)
	if err != nil {
		return []string{indent + dimStyle.Render(text.Truncate(md, 200))}
	}
	var out []string
	for _, l := range strings.Split(strings.Trim(rendered, "\n"), "\n") {
		out = append(out, indent+strings.TrimRight(l, " "))
	}
	return out
}

func first(lines []string) string {
	if len(lines) == 0 {
		return ""
	}
	return lines[0]
}

func rest(lines []string) []string {
	if len(lines) <= 1 {
		return nil
	}
	return lines[1:]
}

// wrap word-wraps plain (ANSI-free) text, hard-breaking tokens wider
// than the pane (paths, URLs).
func wrap(s string, width int) []string {
	if width <= 4 {
		return []string{clip(s, max(1, width))}
	}
	var words []string
	for _, word := range strings.Split(s, " ") {
		r := []rune(word)
		for len(r) > width {
			words = append(words, string(r[:width]))
			r = r[width:]
		}
		words = append(words, string(r))
	}
	var lines []string
	cur := ""
	for _, word := range words {
		switch {
		case cur == "":
			cur = word
		case len([]rune(cur))+1+len([]rune(word)) > width:
			lines = append(lines, cur)
			cur = word
		default:
			cur += " " + word
		}
	}
	if cur != "" {
		lines = append(lines, cur)
	}
	return lines
}

func hhmm(iso string) string {
	if len(iso) >= 16 {
		return iso[11:16]
	}
	return iso
}
