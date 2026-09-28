#!/usr/bin/env bash
#
# tmux-agent-spinner - animates the working indicator in the window pill.
#
# The pill renders @agent_status verbatim (see docs/tmux-agent-protocol.md),
# but a status is a lifecycle word, not an animation. This helper supplies the
# missing half: it cycles the 8-dot braille frames into the global
# @agent_spinner option, and the pill substitutes that option whenever a pane
# reports @agent_status=working. Other tokens keep rendering verbatim.
#
# The clock has to live outside the server. tmux only re-expands a status
# format when something redraws it, and the only in-server timer is
# status-interval, whose floor is one second. So each frame costs one tmux
# client invocation, ~15ms here: at 0.1s per frame that is ~15% of one core,
# and only while an agent is working. frame_period is the knob. A control-mode
# connection would be nearly free but attaches a client to a session, and
# session pickers use #{session_attached} to find detached sessions - not
# worth breaking.
#
# Writing the option is itself the redraw trigger: tmux redraws the status
# line when an option its format reads changes, so no refresh-client is
# needed. While idle the loop rewrites the same frame, which tmux sees as no
# change, so an idle server redraws nothing.
#
# The frame is one global option rather than per-pane state: every working
# window shows the same phase from a single clock, and there is nothing to
# clean up per pane.
#
# Started once per server via `run-shell -b` in tmux.conf. A config reload
# starts a second copy, which the lock turns into an immediate exit.

set -euo pipefail

# The 8-dot braille rotation (cli-spinners' "dots8"), not the 6-dot one agent
# TUIs spin in their own UI. Ghostty draws every braille codepoint itself, as a
# full-cell 2x4 sprite laid out top to bottom (font/sprite/draw/braille.zig), so
# a 6-dot frame lights only the top three of the four dot rows: it renders a
# whole dot row high next to the x-height window name, and because each frame
# lights a different subset the ink also bobs by a row per revolution. All eight
# of these frames light all four rows with one identical ink box, which the
# sprite centers in the cell - the axis the window name sits on.
frames=(⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷)
frame_period=0.1 # seconds per frame while working: one revolution per second
idle_period=1    # seconds between working-set checks while nothing is working

# One instance per server. The lock is held for the whole process lifetime, so
# a copy started by a reload exits instead of racing this one for the option.
# Every child is spawned with the descriptor closed (`9>&-`): a tmux client or
# sleep that outlives this process would otherwise keep a dead instance's lock
# alive and lock out its replacement.
socket=$(tmux display-message -p '#{socket_path}')
exec 9>"$socket.spinner.lock"
flock -n 9 || exit 0

frame=0
while :; do
	# One invocation does both jobs: publish the frame, and report whether any
	# pane is still working so the loop knows how long to sleep.
	working=$(
		tmux set-option -gq @agent_spinner "${frames[frame]}" \; \
			list-panes -a -f '#{==:#{@agent_status},working}' -F x 9>&-
	) || {
		sleep "$idle_period" 9>&-
		continue
	}

	if [[ -n "$working" ]]; then
		frame=$(( (frame + 1) % ${#frames[@]} ))
		sleep "$frame_period" 9>&-
	else
		sleep "$idle_period" 9>&-
	fi
done
