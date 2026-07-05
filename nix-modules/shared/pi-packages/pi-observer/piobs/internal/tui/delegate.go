package tui

import (
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"charm.land/bubbles/v2/list"
	"charm.land/bubbles/v2/spinner"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"

	"piobs/internal/store"
	"piobs/internal/text"
)

type sessionItem struct {
	info store.SessionInfo
}

func (i sessionItem) FilterValue() string {
	return i.info.SessionName + " " + i.info.LastPrompt + " " + i.info.Cwd
}

func (i sessionItem) title() string {
	switch {
	case i.info.SessionName != "":
		return i.info.SessionName
	case i.info.LastPrompt != "":
		return i.info.LastPrompt
	default:
		return "(no prompt yet)"
	}
}

// sessionDelegate renders one session as up to three rows: state marker +
// title, cwd - model - age, and the live activity line while working.
type sessionDelegate struct {
	spin *spinner.Model
}

func (d *sessionDelegate) Height() int                         { return 3 }
func (d *sessionDelegate) Spacing() int                        { return 1 }
func (d *sessionDelegate) Update(tea.Msg, *list.Model) tea.Cmd { return nil }

func (d *sessionDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	it, ok := item.(sessionItem)
	if !ok {
		return
	}
	s := it.info
	width := m.Width()
	selected := index == m.Index()
	exited := s.EffectiveState == store.Exited

	var marker string
	switch s.EffectiveState {
	case store.Working:
		marker = d.spin.View()
	case store.Idle:
		marker = blueStyle.Render("●")
	default:
		marker = dimStyle.Render("○")
	}

	edge := " "
	if selected {
		edge = cyanStyle.Render("▎")
	}

	title := clip(text.Collapse(it.title()), width-5)
	if exited {
		title = dimStyle.Render(title)
	}
	row1 := fmt.Sprintf("%s%s %s", edge, marker, title)

	meta := fmt.Sprintf("%s · %s · %s", tildify(s.Cwd), modelShort(s.Model), age(s.UpdatedAt))
	row2 := fmt.Sprintf("%s  %s", edge, dimStyle.Render(clip(meta, width-4)))

	row3 := ""
	if s.EffectiveState == store.Working && s.CurrentActivity != "" {
		row3 = fmt.Sprintf("%s  %s", edge, greyStyle.Render(clip("↳ "+text.Collapse(s.CurrentActivity), width-6)))
	}

	rows := []string{row1, row2, row3}
	if selected {
		for i, r := range rows {
			rows[i] = selectedBg.Width(width).Render(r)
		}
	}
	fmt.Fprint(w, strings.Join(rows, "\n"))
}

func modelShort(model string) string {
	if model == "" {
		return "?"
	}
	if _, after, found := strings.Cut(model, "/"); found {
		return after
	}
	return model
}

func age(iso string) string {
	t, err := time.Parse(time.RFC3339, iso)
	if err != nil {
		return "?"
	}
	s := int(time.Since(t).Seconds())
	if s < 0 {
		s = 0
	}
	switch {
	case s < 60:
		return fmt.Sprintf("%ds", s)
	case s < 3600:
		return fmt.Sprintf("%dm", s/60)
	case s < 86400:
		return fmt.Sprintf("%dh", s/3600)
	default:
		return fmt.Sprintf("%dd", s/86400)
	}
}

func clip(s string, max int) string {
	if max <= 0 {
		return ""
	}
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return string(r[:max-1]) + "…"
}

func tildify(path string) string {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return path
	}
	if path == home {
		return "~"
	}
	if strings.HasPrefix(path, home+"/") {
		return "~" + path[len(home):]
	}
	return path
}

// --- shared styles ---------------------------------------------------------

var (
	dimStyle   = lipgloss.NewStyle().Faint(true)
	greyStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("245"))
	cyanStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("45"))
	blueStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("75"))
	green      = lipgloss.Color("82")
	greenStyle = lipgloss.NewStyle().Foreground(green)
	selectedBg = lipgloss.NewStyle().Background(lipgloss.Color("237"))
)
