package tui

import (
	"fmt"
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"

	"piobs/internal/session"
	"piobs/internal/store"
	"piobs/internal/text"
)

const rawViewItems = 80

// layout recomputes pane sizes from the window size.
func (m *model) layout() {
	if m.width == 0 || m.height == 0 {
		return
	}
	leftW := m.leftWidth()
	rightW := m.width - leftW - 1
	bodyH := m.height - 1

	m.list.SetSize(leftW, bodyH)
	m.viewport.SetWidth(rightW)
	m.viewport.SetHeight(max(0, bodyH-max(3, len(m.header))))
	m.help.SetWidth(m.width)
	m.feed.setWidth(rightW)
}

func (m *model) leftWidth() int {
	w := min(46, max(30, m.width*36/100))
	// degenerate terminals: keep the right pane at least 5 cells wide
	return max(1, min(w, m.width-6))
}

// refreshFeed rebuilds the right-pane header and re-renders the feed
// content into the viewport.
func (m *model) refreshFeed() {
	if m.width == 0 {
		return
	}
	doc, ok := m.selected()
	if !ok {
		m.header = nil
		m.viewport.SetContent(dimStyle.Render(" select a session"))
		return
	}

	feed := m.st.ReadFeed(doc.SessionID)
	m.header = m.buildHeader(doc, feed)
	m.viewport.SetHeight(max(0, m.height-1-len(m.header)))

	var lines []string
	if banner := m.banner(); banner != "" {
		lines = append(lines, banner)
	}

	switch {
	case m.zoom == ZoomRaw:
		lines = append(lines, m.renderRaw(doc)...)
	default:
		if len(feed) == 0 {
			lines = append(lines,
				"",
				dimStyle.Render(" nothing distilled yet"),
				dimStyle.Render(" press g to distill now, or wait for activity"),
			)
		} else {
			lines = append(lines, m.feed.render(doc.SessionID, feed, m.zoom, m.expandHist)...)
		}
	}

	m.viewport.SetContent(strings.Join(lines, "\n"))
	if m.follow {
		m.viewport.GotoBottom()
	}
}

// buildHeader is the "now" block: title, meta, current phase (+age),
// live activity, and the distiller's rolling summary. It answers "what
// is this session doing" without reading the feed.
func (m *model) buildHeader(doc store.SessionInfo, feed []store.FeedEntry) []string {
	width := m.width - m.leftWidth() - 1

	stateStyle := dimStyle
	switch doc.EffectiveState {
	case store.Working:
		stateStyle = greenStyle
	case store.Idle:
		stateStyle = idleStyle
	}
	title := doc.SessionName
	if title == "" {
		title = doc.LastPrompt
	}
	if title == "" {
		title = doc.SessionID
	}
	rawTag := ""
	if m.zoom == ZoomRaw {
		rawTag = " " + lipgloss.NewStyle().Foreground(lipgloss.Color("220")).Render("[raw]")
	}
	lines := []string{
		" " + stateStyle.Render("●") + " " +
			lipgloss.NewStyle().Bold(true).Render(clip(text.Collapse(title), width-12)) + rawTag,
		"   " + dimStyle.Render(clip(fmt.Sprintf("%s · %s · %s · %s ago",
			doc.EffectiveState, tildify(doc.Cwd), orQuestion(doc.Model), age(doc.UpdatedAt)), width-4)),
	}

	if doc.EffectiveState != store.Exited {
		if phase := lastPhase(feed); phase != nil {
			lines = append(lines, "   "+cyanStyle.Render(clip("▶ "+text.Collapse(phase.Text)+" · "+age(phase.T), width-4)))
		}
	}
	if doc.EffectiveState == store.Working && doc.CurrentActivity != "" {
		lines = append(lines, "   "+greenStyle.Render(clip("↳ "+text.Collapse(doc.CurrentActivity), width-4)))
	}
	// Rolling summary: goal, approach, position - computed by the
	// distiller anyway, shown here instead of buried in state.json.
	if st := m.st.ReadState(doc.SessionID); st != nil && st.State != "" {
		summary := wrap(text.Collapse(st.State), max(10, width-6))
		if len(summary) > 2 {
			summary = summary[:2]
			summary[1] = clip(summary[1]+"…", width-6)
		}
		for _, l := range summary {
			lines = append(lines, "   "+dimStyle.Render(l))
		}
	}

	lines = append(lines, dimStyle.Render(strings.Repeat("─", max(0, width))))
	return lines
}

// lastPhase returns the most recent phase entry, or nil.
func lastPhase(feed []store.FeedEntry) *store.FeedEntry {
	for i := len(feed) - 1; i >= 0; i-- {
		if feed[i].Kind == store.KindPhase {
			return &feed[i]
		}
	}
	return nil
}

// banner is the persistent distiller-misconfiguration line: unlike a
// status flash, it must stay visible until fixed.
func (m *model) banner() string {
	if m.distillerErr == nil {
		return ""
	}
	return lipgloss.NewStyle().Foreground(lipgloss.Color("220")).
		Render(fmt.Sprintf(" ⚠ distiller disabled: %v", m.distillerErr))
}

func (m *model) renderRaw(doc store.SessionInfo) []string {
	if doc.SessionFile == "" {
		return []string{dimStyle.Render(" ephemeral session (--no-session): no content source")}
	}
	// Session files grow large; a full parse per 1s tick would stall the
	// update loop. Reuse the cache until the file (or pane) changes.
	width := m.viewport.Width()
	size := m.sizes[doc.SessionID].size
	c := &m.rawCache
	if c.sessionID == doc.SessionID && c.size == size && c.width == width && c.lines != nil {
		return c.lines
	}
	res := session.ParseSince(doc.SessionFile, 0)
	items := res.Items
	if len(items) > rawViewItems {
		items = items[len(items)-rawViewItems:]
	}
	var out []string
	for _, line := range strings.Split(session.RenderItems(items), "\n") {
		for _, l := range wrap(line, width-2) {
			out = append(out, " "+l)
		}
	}
	*c = rawCache{sessionID: doc.SessionID, size: size, width: width, lines: out}
	return out
}

// --- View ------------------------------------------------------------------

func (m *model) View() tea.View {
	if m.width == 0 || m.height == 0 {
		v := tea.NewView("")
		v.AltScreen = true
		return v
	}
	leftW := m.leftWidth()
	rightW := m.width - leftW - 1
	bodyH := m.height - 1

	left := lipgloss.NewStyle().Width(leftW).Height(bodyH).MaxHeight(bodyH).Render(m.list.View())
	divider := strings.TrimSuffix(strings.Repeat(dimStyle.Render("│")+"\n", bodyH), "\n")
	right := lipgloss.NewStyle().Width(rightW).Height(bodyH).MaxHeight(bodyH).
		Render(m.rightPane(rightW))

	body := lipgloss.JoinHorizontal(lipgloss.Top, left, divider, right)
	v := tea.NewView(body + "\n" + m.statusBar())
	v.AltScreen = true
	return v
}

func (m *model) rightPane(width int) string {
	if _, ok := m.selected(); !ok {
		return dimStyle.Render(" no sessions yet")
	}
	return strings.Join(append(append([]string{}, m.header...), m.viewport.View()), "\n")
}

func (m *model) statusBar() string {
	var parts []string
	if m.distilling {
		parts = append(parts, m.spin.View()+greenStyle.Render(" distilling"))
	}
	if m.status != "" && time.Now().Before(m.statusUntil) {
		parts = append(parts, lipgloss.NewStyle().Foreground(lipgloss.Color("220")).Render(m.status))
	}
	parts = append(parts, m.help.View(m.keys))
	bar := " " + strings.Join(parts, "  ")
	return lipgloss.NewStyle().Background(lipgloss.Color("236")).
		Width(m.width).MaxHeight(1).Render(bar)
}

func orQuestion(s string) string {
	if s == "" {
		return "?"
	}
	return s
}
