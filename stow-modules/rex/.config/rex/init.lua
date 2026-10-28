-- Familiar tmux keys on Rex's own panes, tabs, and persistent sessions.
-- Keep the client's default shortcuts; Ctrl+Q is an additional entry point.
-- Escape cancels a sequence; Ctrl+Q twice sends Ctrl+Q to the terminal.
rex.bind("ctrl+q>ctrl+q", "pane.send_key", { key = "ctrl+q" })

rex.bind("ctrl+q>v", "pane.split", { direction = "right" })
rex.bind("ctrl+q>s", "pane.split", { direction = "down" })
rex.bind("ctrl+q>h", "pane.focus", { direction = "left" })
rex.bind("ctrl+q>j", "pane.focus", { direction = "down" })
rex.bind("ctrl+q>k", "pane.focus", { direction = "up" })
rex.bind("ctrl+q>l", "pane.focus", { direction = "right" })
rex.bind("ctrl+q>z", "pane.zoom")
rex.bind("ctrl+q>x", "pane.close")

-- A tmux window corresponds to a Rex tab, not a native app window.
rex.bind("ctrl+q>c", "client.tab.new")
rex.bind("ctrl+q>n", "client.tab.next")
rex.bind("ctrl+q>p", "client.tab.previous")
rex.bind("ctrl+q>shift+h", "client.tab.previous")
rex.bind("ctrl+q>shift+l", "client.tab.next")
for index = 1, 9 do
    rex.bind("ctrl+q>" .. index, "client.tab.goto", { index = index })
end

-- Use Rex's session picker instead of recreating tms or nesting tmux.
rex.bind("ctrl+q>w", "session.switch")
rex.bind("ctrl+q>shift+w", "session.new")
-- Native program activity replaces the tmux agent-pane popup/status plugin.
rex.bind("ctrl+q>a", "client.sidebar.activity.toggle")
rex.bind("ctrl+q>r", "client.config.reload")
rex.bind("ctrl+q>shift+;", "client.palette.toggle")

-- Persistent font and theme settings live in nix-modules/darwin/rex.plist.
-- nix-darwin imports them into the native client's preferences on activation.
