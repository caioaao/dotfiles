package tui

import (
	"strings"

	"charm.land/lipgloss/v2"

	"piobs/internal/store"
	"piobs/internal/text"
)

// docview renders the distiller's living brief (store.SessionDoc) with a
// fixed skeleton: NOW first, WAITING second, adaptive sections in a
// fixed priority order, SO FAR last. The model chooses which sections
// exist; it never chooses the layout - spatial stability is what makes
// the pane glanceable.

var sectionOrder = map[string]int{
	store.SectionPlan:       0,
	store.SectionHypotheses: 1,
	store.SectionFindings:   2,
	store.SectionDecisions:  3,
	store.SectionRisks:      4,
	// unknown kinds sort after known ones (see sectionRank)
}

func sectionRank(kind string) int {
	if r, ok := sectionOrder[kind]; ok {
		return r
	}
	return len(sectionOrder)
}

var sectionTitles = map[string]string{
	store.SectionPlan:       "PLAN",
	store.SectionHypotheses: "HYPOTHESES",
	store.SectionFindings:   "FINDINGS",
	store.SectionDecisions:  "DECISIONS",
	store.SectionRisks:      "RISKS",
}

// itemGlyph maps DocItem states to glyph + style. Unknown/empty states
// render as a plain bullet, per the open-enum rule.
func itemGlyph(state string) string {
	switch state {
	case "done", "confirmed":
		return greenStyle.Render("✔")
	case "doing":
		return cyanStyle.Render("◐")
	case "todo":
		return dimStyle.Render("○")
	case "ruledout":
		return dimStyle.Render("✗")
	case "open":
		return greyStyle.Render("?")
	default:
		return dimStyle.Render("•")
	}
}

var (
	labelStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("45")).Bold(true)
	waitingLabel = lipgloss.NewStyle().Foreground(lipgloss.Color("214")).Bold(true)
	waitingText  = lipgloss.NewStyle().Foreground(lipgloss.Color("214"))
	proseStyle   = lipgloss.NewStyle()
	storyStyle   = lipgloss.NewStyle().Faint(true)
	ruledOut     = lipgloss.NewStyle().Faint(true).Strikethrough(true)
)

// renderDoc renders the living brief into terminal lines. width is the
// pane width; the text measure is capped like the feed's.
func renderDoc(doc *store.SessionDoc, width int) []string {
	w := max(10, min(width-4, maxMeasure))
	var out []string

	block := func(label string, labelSty lipgloss.Style, body string, bodySty lipgloss.Style) {
		if body == "" {
			return
		}
		out = append(out, " "+labelSty.Render(label))
		for _, l := range wrap(text.Collapse(body), w) {
			out = append(out, "   "+bodySty.Render(l))
		}
		out = append(out, "")
	}

	out = append(out, "")
	block("NOW", labelStyle, doc.Now, proseStyle)
	block("WAITING ON YOU", waitingLabel, doc.Waiting, waitingText)

	for _, sec := range sortedSections(doc.Sections) {
		title, ok := sectionTitles[sec.Kind]
		if !ok {
			title = strings.ToUpper(sec.Kind)
		}
		out = append(out, " "+labelStyle.Render(title))
		if sec.Text != "" {
			for _, l := range wrap(text.Collapse(sec.Text), w) {
				out = append(out, "   "+l)
			}
		}
		for _, it := range sec.Items {
			sty := proseStyle
			if it.State == "ruledout" {
				sty = ruledOut
			}
			lines := wrap(text.Collapse(it.Text), w-2)
			out = append(out, "   "+itemGlyph(it.State)+" "+sty.Render(first(lines)))
			for _, cont := range rest(lines) {
				out = append(out, "     "+sty.Render(cont))
			}
		}
		out = append(out, "")
	}

	block("SO FAR", labelStyle, doc.Story, storyStyle)

	// drop the trailing blank line
	if n := len(out); n > 0 && out[n-1] == "" {
		out = out[:n-1]
	}
	return out
}

// sortedSections orders sections by the fixed priority, keeping the
// model's relative order within equal ranks (stable).
func sortedSections(secs []store.DocSection) []store.DocSection {
	out := append([]store.DocSection(nil), secs...)
	// insertion sort: n <= 5, stability required
	for i := 1; i < len(out); i++ {
		for j := i; j > 0 && sectionRank(out[j].Kind) < sectionRank(out[j-1].Kind); j-- {
			out[j], out[j-1] = out[j-1], out[j]
		}
	}
	return out
}
