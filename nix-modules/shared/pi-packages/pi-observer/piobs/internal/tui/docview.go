package tui

import (
	"charm.land/lipgloss/v2"

	"piobs/internal/store"
	"piobs/internal/text"
)

// docview renders the distiller's living brief (store.SessionDoc) with a
// fixed skeleton: NOW first, SO FAR last. Spatial stability is what
// makes the pane glanceable.

var (
	labelStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("45")).Bold(true)
	proseStyle = lipgloss.NewStyle()
	storyStyle = lipgloss.NewStyle().Faint(true)
)

// renderDoc renders the living brief into terminal lines. width is the
// pane width; the text measure is capped like the feed's.
func renderDoc(doc *store.SessionDoc, width int) []string {
	w := max(10, min(width-4, maxMeasure))
	var out []string

	block := func(label string, body string, bodySty lipgloss.Style) {
		if body == "" {
			return
		}
		out = append(out, " "+labelStyle.Render(label))
		for _, l := range wrap(text.Collapse(body), w) {
			out = append(out, "   "+bodySty.Render(l))
		}
		out = append(out, "")
	}

	out = append(out, "")
	block("NOW", doc.Now, proseStyle)
	block("SO FAR", doc.Story, storyStyle)

	// drop the trailing blank line
	if n := len(out); n > 0 && out[n-1] == "" {
		out = out[:n-1]
	}
	return out
}
