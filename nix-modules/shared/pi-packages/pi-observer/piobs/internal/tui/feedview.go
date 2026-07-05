package tui

import (
	"image/color"
	"strings"

	"charm.land/glamour/v2"
	"charm.land/lipgloss/v2"

	"piobs/internal/store"
	"piobs/internal/text"
)

// maxMeasure caps the text column: full-width lines on wide terminals
// are unscannable, and scanning is the whole point of the feed.
const maxMeasure = 100

// Zoom levels: how much altitude the feed gives up.
//
//	1 headline: prompts, phases, outcomes (whole session in one screen)
//	2 story:    + insights, backtracks, notes (default)
//	3 deep:     + details
//	4 raw:      undistilled activity (handled by the view layer)
const (
	ZoomHeadline = 1
	ZoomStory    = 2
	ZoomDeep     = 3
	ZoomRaw      = 4
)

func zoomName(z int) string {
	switch z {
	case ZoomHeadline:
		return "headline"
	case ZoomStory:
		return "story"
	case ZoomDeep:
		return "deep"
	default:
		return "raw"
	}
}

// kindStyle describes how one feed kind renders: badge glyph, badge
// color, and how the text body is painted.
type kindStyle struct {
	badge string
	color color.Color
	// paintText: color the whole text line with color (phases get bold)
	paintText bool
	dimText   bool
}

// Three semantic color groups, not one color per kind: attention
// (error red, backtrack yellow), progress (phase cyan, done green,
// prompt bold white), background (insight plain, note dim).
var kindStyles = map[store.FeedKind]kindStyle{
	store.KindPhase:     {badge: "▶", color: lipgloss.Color("45"), paintText: true},
	store.KindInsight:   {badge: "✦", color: lipgloss.Color("250")},
	store.KindNote:      {badge: "·", color: lipgloss.Color("245"), dimText: true},
	store.KindBacktrack: {badge: "↩", color: lipgloss.Color("220"), paintText: true},
	store.KindDone:      {badge: "✔", color: lipgloss.Color("82"), paintText: true},
	store.KindError:     {badge: "✖", color: lipgloss.Color("196"), paintText: true},
	store.KindPrompt:    {badge: "❯", color: lipgloss.Color("231")},
}

// feedView renders feed entries into terminal lines, caching the whole
// output keyed on (sessionId, width, zoom, expandHist, entryCount).
// Folding makes prefix-incremental caching impossible (a new prompt
// collapses the previous group), but folded groups skip glamour, so a
// full re-render on append stays cheap.
type feedView struct {
	sessionID  string
	width      int
	zoom       int
	expandHist bool
	count      int
	lines      []string
	renderer   *glamour.TermRenderer
}

func (f *feedView) invalidate() { f.count = 0; f.lines = nil }

// measure is the effective text width for wrapped body text.
func (f *feedView) measure() int { return min(f.width-10, maxMeasure) }

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
		glamour.WithWordWrap(max(20, min(w-6, maxMeasure))),
	)
	if err == nil {
		f.renderer = r
	}
}

// group is one prompt-turn: the prompt entry (nil for the pre-prompt
// preamble) plus everything until the next prompt.
type group struct {
	prompt  *store.FeedEntry
	entries []store.FeedEntry
}

func groupByPrompt(entries []store.FeedEntry) []group {
	var groups []group
	cur := group{}
	for _, e := range entries {
		if e.Kind == store.KindPrompt {
			if cur.prompt != nil || len(cur.entries) > 0 {
				groups = append(groups, cur)
			}
			e := e
			cur = group{prompt: &e}
			continue
		}
		cur.entries = append(cur.entries, e)
	}
	if cur.prompt != nil || len(cur.entries) > 0 {
		groups = append(groups, cur)
	}
	return groups
}

// visible filters kinds by zoom: headline keeps turn boundaries,
// phases, and outcomes; story adds the rest.
func (f *feedView) visible(k store.FeedKind) bool {
	if f.zoom >= ZoomStory {
		return true
	}
	switch k {
	case store.KindPrompt, store.KindPhase, store.KindDone, store.KindError, store.KindBacktrack:
		return true
	}
	return false
}

// render returns the terminal lines for the given feed, reusing the
// cached render when nothing changed.
func (f *feedView) render(sessionID string, entries []store.FeedEntry, zoom int, expandHist bool) []string {
	if sessionID == f.sessionID && zoom == f.zoom && expandHist == f.expandHist &&
		len(entries) == f.count && f.lines != nil {
		return f.lines
	}
	f.sessionID, f.zoom, f.expandHist, f.count = sessionID, zoom, expandHist, len(entries)

	groups := groupByPrompt(entries)
	var out []string
	lastTime := ""
	for gi, g := range groups {
		// Finished turns fold to prompt + outcome: only the current turn
		// competes for attention. x expands history back.
		if !expandHist && g.prompt != nil && gi < len(groups)-1 {
			out = append(out, f.renderFolded(g)...)
			lastTime = ""
			continue
		}
		if g.prompt != nil {
			out = append(out, f.renderEntry(*g.prompt, &lastTime)...)
		}
		for _, e := range g.entries {
			if !f.visible(e.Kind) {
				continue
			}
			out = append(out, f.renderEntry(e, &lastTime)...)
		}
	}
	f.lines = out
	return out
}

// renderFolded renders a completed turn as two clipped lines: the prompt
// and its outcome (done/error), everything in between suppressed.
func (f *feedView) renderFolded(g group) []string {
	w := f.measure()
	out := []string{"", f.rule()}
	pStyle := kindStyles[store.KindPrompt]
	badge := lipgloss.NewStyle().Foreground(pStyle.color).Render(pStyle.badge)
	out = append(out, " "+dimStyle.Render(hhmm(g.prompt.T))+" "+badge+" "+
		dimStyle.Render(clip(text.Collapse(g.prompt.Text), w)))

	if oc := outcomeOf(g); oc != nil {
		style := kindStyles[oc.Kind]
		obadge := lipgloss.NewStyle().Foreground(style.color).Render(style.badge)
		out = append(out, "       "+obadge+" "+dimStyle.Render(clip(text.Collapse(oc.Text), w)))
	}
	return out
}

// outcomeOf picks the folded group's one-line summary: last error wins
// over last done; otherwise the last phase hints where the turn ended.
func outcomeOf(g group) *store.FeedEntry {
	var done, phase *store.FeedEntry
	for i := range g.entries {
		e := &g.entries[i]
		switch e.Kind {
		case store.KindError:
			return e
		case store.KindDone:
			done = e
		case store.KindPhase:
			phase = e
		}
	}
	if done != nil {
		return done
	}
	return phase
}

func (f *feedView) rule() string {
	return dimStyle.Render(" " + strings.Repeat("┄", max(0, min(f.width-2, maxMeasure+8))))
}

// renderEntry renders one expanded entry. lastTime dedupes the clock
// column: repeated timestamps are noise, only changes are signal.
func (f *feedView) renderEntry(e store.FeedEntry, lastTime *string) []string {
	style, ok := kindStyles[e.Kind]
	if !ok {
		style = kindStyles[store.KindNote] // unknown kinds render as note, per contract
	}
	timeStr := strings.Repeat(" ", 5)
	if hm := hhmm(e.T); hm != *lastTime {
		timeStr = dimStyle.Render(hm)
		*lastTime = hm
	}
	badge := lipgloss.NewStyle().Foreground(style.color).Render(style.badge)

	// Phases are section headers; everything else nests under them.
	indent := "  "
	if e.Kind == store.KindPhase || e.Kind == store.KindPrompt || e.Kind == store.KindDone {
		indent = ""
	}
	textLines := wrap(text.Collapse(e.Text), f.measure()-len(indent))
	contIndent := "       " + indent + "  "

	var out []string

	// Prompts are turn boundaries: rule + blank line chunk the feed
	// visually.
	if e.Kind == store.KindPrompt {
		out = append(out, "", f.rule())
		bold := lipgloss.NewStyle().Bold(true)
		out = append(out, " "+timeStr+" "+badge+" "+bold.Render(first(textLines)))
		for _, cont := range rest(textLines) {
			out = append(out, contIndent+bold.Render(cont))
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

	out = append(out, " "+timeStr+" "+indent+badge+" "+paint.Render(first(textLines)))
	for _, cont := range rest(textLines) {
		out = append(out, contIndent+paint.Render(cont))
	}

	// Details are the other markdown spot; glamour-rendered at deep zoom.
	if f.zoom >= ZoomDeep && e.Detail != "" {
		out = append(out, f.markdown(e.Detail, "     "+indent)...)
	}
	return out
}

// markdown renders a snippet through glamour and indents it. Falls back
// to plain wrapped text when the renderer is unavailable.
func (f *feedView) markdown(md, indent string) []string {
	if f.renderer == nil {
		var out []string
		for _, l := range wrap(md, f.measure()-2) {
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
