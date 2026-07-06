// Package tui is the piobs Bubble Tea app: session list (left) +
// distilled feed (right).
//
// Elm architecture: one root model, all I/O in tea.Cmds, never in Update.
// Only the selected session distills in real time; selecting a session
// that fell behind triggers catch-up. Selecting another session cancels
// an in-flight distill.
package tui

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"charm.land/bubbles/v2/help"
	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/list"
	"charm.land/bubbles/v2/spinner"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"

	"piobs/internal/distill"
	"piobs/internal/store"
)

const (
	tickInterval = time.Second
	debounce     = 2500 * time.Millisecond
	statusTTL    = 4 * time.Second
	errStatusTTL = 8 * time.Second

	// Auto-distill policy: narrating history costs real tokens, so it
	// only happens when someone plausibly wants it. Rotten sessions
	// (exited > rottenAfter) and oversized backlogs are archaeology -
	// distilling them is opt-in ('g'), announced by a pane notice.
	rottenAfter    = 5 * time.Minute
	autoBacklogMax = int64(200 << 10)
	// errBackoff throttles retries after a failed distill; without it a
	// persistent API error is re-hit every tick.
	errBackoff = 30 * time.Second
)

// Run starts the TUI and blocks until quit.
func Run(st *store.Store) error {
	st.GC(14)
	m := newModel(st)
	_, err := tea.NewProgram(m).Run()
	return err
}

// --- messages ------------------------------------------------------------

type tickMsg time.Time

type sessionsLoadedMsg struct {
	sessions []store.SessionInfo
	// sizes maps sessionId -> current session-file size (for debounce).
	sizes map[string]int64
	// summaries maps sessionId -> distiller rolling state (list titles).
	summaries map[string]string
}

type distillDoneMsg struct {
	sessionID string
	n         int
	err       error
}

type statusNote struct {
	text string
	ttl  time.Duration
}

// --- keymap --------------------------------------------------------------

type keymap struct {
	Nav       key.Binding
	Hop       key.Binding
	Filter    key.Binding
	Follow    key.Binding
	Zoom      key.Binding
	Expand    key.Binding
	Subs      key.Binding
	Distill   key.Binding
	Redistill key.Binding
	Quit      key.Binding
}

func newKeymap() keymap {
	return keymap{
		// Nav is help-only: the list component owns j/k. Arrows scroll
		// the feed, so without this hint session switching is
		// undiscoverable.
		Nav:       key.NewBinding(key.WithKeys("j", "k"), key.WithHelp("j/k", "session")),
		Hop:       key.NewBinding(key.WithKeys("enter"), key.WithHelp("↵", "hop")),
		Filter:    key.NewBinding(key.WithKeys("/"), key.WithHelp("/", "filter")),
		Follow:    key.NewBinding(key.WithKeys("f"), key.WithHelp("f", "follow")),
		Zoom:      key.NewBinding(key.WithKeys("1", "2", "3", "4"), key.WithHelp("1-4", "zoom")),
		Expand:    key.NewBinding(key.WithKeys("x"), key.WithHelp("x", "history")),
		Subs:      key.NewBinding(key.WithKeys("s"), key.WithHelp("s", "subagents")),
		Distill:   key.NewBinding(key.WithKeys("g"), key.WithHelp("g", "distill")),
		Redistill: key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "redistill")),
		Quit:      key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "quit")),
	}
}

func (k keymap) ShortHelp() []key.Binding {
	return []key.Binding{k.Nav, k.Hop, k.Filter, k.Follow, k.Zoom, k.Expand, k.Subs, k.Distill, k.Redistill, k.Quit}
}

func (k keymap) FullHelp() [][]key.Binding { return [][]key.Binding{k.ShortHelp()} }

// --- model ---------------------------------------------------------------

type sizeTrack struct {
	size      int64
	changedAt time.Time
}

type model struct {
	st        *store.Store
	distiller *distill.Distiller
	// distillerErr is a persistent banner (missing API key, bad
	// provider): distill failures must be seen, not flash by.
	distillerErr error

	width, height int
	list          list.Model
	viewport      viewport.Model
	spin          spinner.Model
	help          help.Model
	keys          keymap

	follow bool
	// zoom is the feed altitude (see feedview.go Zoom* constants).
	zoom int
	// expandHist shows finished turns unfolded.
	expandHist bool
	// hideSub hides subagent sessions (those with a resolved parent).
	hideSub bool

	status      string
	statusUntil time.Time

	distilling bool
	// backoffUntil pauses auto-distill after a failure (rate limit,
	// overload); force ('g') bypasses it.
	backoffUntil time.Time
	cancel       context.CancelFunc
	// pendingRedistill queues a clear+force-distill requested while a
	// distill was in flight (which had to be cancelled first).
	pendingRedistill bool
	loadingSessions  bool

	sizes map[string]sizeTrack

	// sessions/summaries are the last loaded snapshot; rebuildItems
	// re-derives the visible list from them (subagent filter).
	sessions  []store.SessionInfo
	summaries map[string]string

	// header is the right-pane header block, rebuilt by refreshFeed.
	header []string

	feed     feedView
	rawCache rawCache
}

// rawCache memoizes the raw-view rendering, keyed on the session file's
// identity, size, and the pane width.
type rawCache struct {
	sessionID string
	size      int64
	width     int
	lines     []string
}

func newModel(st *store.Store) *model {
	m := &model{
		st:      st,
		follow:  true,
		hideSub: true,
		zoom:    ZoomStory,
		sizes:   map[string]sizeTrack{},
		keys:    newKeymap(),
		help:    help.New(),
		spin:    spinner.New(spinner.WithSpinner(spinner.MiniDot), spinner.WithStyle(lipgloss.NewStyle().Foreground(green))),
	}
	d, err := distill.New(st, distill.LoadConfig())
	if err != nil {
		m.distillerErr = err
	} else {
		m.distiller = d
	}

	del := &sessionDelegate{spin: &m.spin}
	l := list.New(nil, del, 0, 0)
	l.SetShowTitle(false)
	l.SetShowStatusBar(false)
	l.SetShowHelp(false)
	l.SetFilteringEnabled(true)
	l.DisableQuitKeybindings()
	m.list = l

	m.viewport = viewport.New()
	m.viewport.KeyMap = viewportKeys()
	m.viewport.FillHeight = false

	return m
}

// viewportKeys drops j/k (they move the session list) and keeps
// arrows/paging for feed scrollback.
func viewportKeys() viewport.KeyMap {
	return viewport.KeyMap{
		Up:           key.NewBinding(key.WithKeys("up")),
		Down:         key.NewBinding(key.WithKeys("down")),
		PageUp:       key.NewBinding(key.WithKeys("pgup")),
		PageDown:     key.NewBinding(key.WithKeys("pgdown")),
		HalfPageUp:   key.NewBinding(key.WithKeys("ctrl+u")),
		HalfPageDown: key.NewBinding(key.WithKeys("ctrl+d")),
	}
}

func (m *model) Init() tea.Cmd {
	return tea.Batch(m.loadSessions, m.tick(), m.spin.Tick)
}

func (m *model) tick() tea.Cmd {
	// tea.Tick is one-shot: re-armed from each tickMsg handler.
	return tea.Tick(tickInterval, func(t time.Time) tea.Msg { return tickMsg(t) })
}

// loadSessions does readdir + pid checks + session-file stats off the
// update loop.
func (m *model) loadSessions() tea.Msg {
	sessions := m.st.ListSessions()
	sizes := map[string]int64{}
	summaries := map[string]string{}
	for _, s := range sessions {
		if st := m.st.ReadState(s.SessionID); st != nil {
			summaries[s.SessionID] = st.State
		}
		if s.SessionFile == "" {
			continue
		}
		if fi, err := os.Stat(s.SessionFile); err == nil {
			sizes[s.SessionID] = fi.Size()
		}
	}
	return sessionsLoadedMsg{sessions: sessions, sizes: sizes, summaries: summaries}
}

func (m *model) selected() (store.SessionInfo, bool) {
	it, ok := m.list.SelectedItem().(sessionItem)
	if !ok {
		return store.SessionInfo{}, false
	}
	return it.info, true
}

// --- update --------------------------------------------------------------

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.layout()
		m.refreshFeed()
		return m, nil

	case tickMsg:
		if m.loadingSessions {
			return m, m.tick()
		}
		m.loadingSessions = true
		return m, tea.Batch(m.tick(), m.loadSessions)

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spin, cmd = m.spin.Update(msg)
		return m, cmd

	case sessionsLoadedMsg:
		return m, m.onSessionsLoaded(msg)

	case distillDoneMsg:
		m.distilling = false
		if m.cancel != nil {
			m.cancel()
			m.cancel = nil
		}
		if msg.err != nil && !isCanceled(msg.err) {
			m.backoffUntil = time.Now().Add(errBackoff)
			m.setStatus(fmt.Sprintf("distill failed (retry in %s): %v", errBackoff, msg.err), errStatusTTL)
		}
		if sel, ok := m.selected(); ok && sel.SessionID == msg.sessionID {
			m.refreshFeed()
		}
		if m.pendingRedistill {
			m.pendingRedistill = false
			return m, m.redistill()
		}
		return m, nil

	case statusNote:
		m.setStatus(msg.text, msg.ttl)
		return m, nil

	case tea.KeyPressMsg:
		return m.onKey(msg)
	}

	// bubble everything else (filter internals, pagination) to the list
	return m, m.updateList(msg)
}

// updateList forwards a message to the list and reacts to fallout: a
// changed selection or a completed refilter both need the feed pane
// rebuilt.
func (m *model) updateList(msg tea.Msg) tea.Cmd {
	before, _ := m.selected()
	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	after, _ := m.selected()
	switch {
	case before.SessionID != after.SessionID:
		m.onSelectionChanged()
	default:
		if _, ok := msg.(list.FilterMatchesMsg); ok {
			m.refreshFeed()
		}
	}
	return cmd
}

func (m *model) onKey(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	// While typing a filter, the list owns the keyboard (except ctrl+c).
	if m.list.SettingFilter() {
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
		return m, m.updateList(msg)
	}

	switch {
	case key.Matches(msg, m.keys.Quit):
		if m.cancel != nil {
			m.cancel()
		}
		return m, tea.Quit

	case key.Matches(msg, m.keys.Hop):
		if sel, ok := m.selected(); ok {
			return m, hopCmd(sel)
		}
		return m, nil

	case key.Matches(msg, m.keys.Follow):
		m.follow = !m.follow
		if m.follow {
			m.viewport.GotoTop()
		}
		m.setStatus(fmt.Sprintf("follow %s", onOff(m.follow)), statusTTL)
		return m, nil

	case key.Matches(msg, m.keys.Zoom):
		m.zoom = int(msg.String()[0] - '0')
		m.refreshFeed()
		m.setStatus(fmt.Sprintf("zoom %d: %s", m.zoom, zoomName(m.zoom)), statusTTL)
		return m, nil

	case key.Matches(msg, m.keys.Expand):
		m.expandHist = !m.expandHist
		m.refreshFeed()
		m.setStatus(fmt.Sprintf("history %s", onOff(m.expandHist)), statusTTL)
		return m, nil

	case key.Matches(msg, m.keys.Subs):
		m.hideSub = !m.hideSub
		cmd := m.rebuildItems()
		m.refreshFeed()
		if m.hideSub {
			m.setStatus("subagent sessions hidden", statusTTL)
		} else {
			m.setStatus("subagent sessions shown", statusTTL)
		}
		return m, cmd

	case key.Matches(msg, m.keys.Distill):
		return m, m.maybeDistill(true)

	case key.Matches(msg, m.keys.Redistill):
		// An in-flight distill would race the feed clear (and resurrect
		// the watermark): cancel it and queue the redistill for its
		// completion message.
		if m.distilling {
			if m.cancel != nil {
				m.cancel()
			}
			m.pendingRedistill = true
			m.setStatus("redistilling from scratch...", statusTTL)
			return m, nil
		}
		return m, m.redistill()
	}

	// Scroll keys go to the viewport; leaving the top (where the brief's
	// NOW block lives) disengages follow, returning to it re-engages.
	var vpCmd tea.Cmd
	m.viewport, vpCmd = m.viewport.Update(msg)
	if vpCmd != nil || isScrollKey(msg) {
		m.follow = m.viewport.AtTop()
		return m, vpCmd
	}

	return m, m.updateList(msg)
}

// redistill clears the selected session's feed and force-distills.
// Callers must ensure no distill is in flight.
func (m *model) redistill() tea.Cmd {
	sel, ok := m.selected()
	if !ok {
		return nil
	}
	if err := m.st.ClearFeed(sel.SessionID); err != nil {
		m.setStatus(fmt.Sprintf("redistill: %v", err), errStatusTTL)
		return nil
	}
	m.feed.invalidate()
	m.refreshFeed()
	m.setStatus("redistilling from scratch...", statusTTL)
	return m.maybeDistill(true)
}

func isScrollKey(msg tea.KeyPressMsg) bool {
	switch msg.String() {
	case "up", "down", "pgup", "pgdown", "ctrl+u", "ctrl+d":
		return true
	}
	return false
}

func (m *model) onSelectionChanged() {
	// cancel in-flight distill for the previous session
	if m.cancel != nil {
		m.cancel()
	}
	m.follow = true
	m.refreshFeed()
	m.viewport.GotoTop()
}

func (m *model) onSessionsLoaded(msg sessionsLoadedMsg) tea.Cmd {
	m.loadingSessions = false
	m.sessions = msg.sessions
	m.summaries = msg.summaries
	cmd := m.rebuildItems()

	now := time.Now()
	for id, size := range msg.sizes {
		if tr, ok := m.sizes[id]; !ok || tr.size != size {
			m.sizes[id] = sizeTrack{size: size, changedAt: now}
		}
	}
	for id := range m.sizes {
		if _, ok := msg.sizes[id]; !ok {
			delete(m.sizes, id) // session gc'd or file gone
		}
	}

	m.refreshFeed()
	return tea.Batch(cmd, m.maybeDistill(false))
}

// rebuildItems re-derives the visible list from the loaded snapshot,
// applying the subagent filter and keeping the selection stable.
func (m *model) rebuildItems() tea.Cmd {
	before, hadSel := m.selected()

	var items []list.Item
	for _, s := range m.sessions {
		if m.hideSub && s.ParentID != "" {
			continue
		}
		items = append(items, sessionItem{info: s, summary: m.summaries[s.SessionID]})
	}
	cmd := m.list.SetItems(items)

	// Keep selection stable across re-sorts. Select operates on visible
	// items, so only remap indices when no filter is applied (SetItems
	// refilters asynchronously; FilterMatchesMsg handles that path).
	if hadSel && m.list.FilterState() == list.Unfiltered {
		for i, it := range items {
			if it.(sessionItem).info.SessionID == before.SessionID {
				m.list.Select(i)
				break
			}
		}
	}
	return cmd
}

// maybeDistill starts an async distill of the selected session when it
// has pending bytes and either settled (no growth for 2.5s), stopped
// working, or was forced. Single-flight: one distill at a time.
// Auto (non-forced) distill additionally skips rotten sessions and
// oversized backlogs (see the policy consts); the feed pane shows a
// notice explaining the skip.
func (m *model) maybeDistill(force bool) tea.Cmd {
	if m.distiller == nil || m.distilling {
		return nil
	}
	doc, ok := m.selected()
	if !ok || doc.SessionFile == "" {
		return nil
	}
	tr, ok := m.sizes[doc.SessionID]
	if !ok {
		return nil
	}
	if !force {
		if time.Now().Before(m.backoffUntil) {
			return nil
		}
		wm := m.st.Watermark(doc.SessionID)
		if tr.size <= wm.UpTo {
			return nil
		}
		if rotten(doc) || tr.size-wm.UpTo > autoBacklogMax {
			return nil
		}
		settled := doc.EffectiveState != store.Working || time.Since(tr.changedAt) > debounce
		if !settled {
			return nil
		}
	}

	ctx, cancel := context.WithCancel(context.Background())
	m.cancel = cancel
	m.distilling = true
	d := m.distiller
	return func() tea.Msg {
		n, err := d.Session(ctx, doc, nil)
		return distillDoneMsg{sessionID: doc.SessionID, n: n, err: err}
	}
}

// rotten: exited long enough that nobody is coming back for it soon.
// A just-exited session still auto-distills (its ending is exactly what
// the human wants to read); an unparseable updatedAt counts as ancient,
// matching gc.
func rotten(s store.SessionInfo) bool {
	if s.EffectiveState != store.Exited {
		return false
	}
	t, err := time.Parse(time.RFC3339, s.UpdatedAt)
	if err != nil {
		return true
	}
	return time.Since(t) > rottenAfter
}

func isCanceled(err error) bool {
	return errors.Is(err, context.Canceled)
}

func (m *model) setStatus(s string, ttl time.Duration) {
	m.status = s
	m.statusUntil = time.Now().Add(ttl)
}

func onOff(b bool) string {
	if b {
		return "on"
	}
	return "off"
}

// hopCmd jumps to the session's tmux pane: three quick tmux calls in a
// Cmd; errors surface as a status message.
func hopCmd(doc store.SessionInfo) tea.Cmd {
	return func() tea.Msg {
		if doc.Tmux == nil || doc.Tmux.Pane == "" {
			return statusNote{fmt.Sprintf("no tmux pane; session file: %s", orNone(doc.SessionFile)), errStatusTTL}
		}
		pane := doc.Tmux.Pane
		out, err := exec.Command("tmux", "display-message", "-p", "-t", pane, "#{session_name}").Output()
		if err != nil {
			return statusNote{fmt.Sprintf("tmux hop failed: %v", err), errStatusTTL}
		}
		session := strings.TrimSpace(string(out))
		for _, args := range [][]string{
			{"switch-client", "-t", session},
			{"select-window", "-t", pane},
			{"select-pane", "-t", pane},
		} {
			if err := exec.Command("tmux", args...).Run(); err != nil {
				return statusNote{fmt.Sprintf("tmux hop failed: %v", err), errStatusTTL}
			}
		}
		return nil
	}
}

func orNone(s string) string {
	if s == "" {
		return "none"
	}
	return s
}
