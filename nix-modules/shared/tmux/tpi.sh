#!/usr/bin/env bash

set -euo pipefail

# @pi_status is published per pane by Pi's tmux-window-name extension.
candidates=$(tmux list-panes -s \
	-f '#{&&:#{@pi_status},#{!=:#{pane_dead},1}}' \
	-F $'#{session_id}:#{window_id}.#{pane_id}\t#{window_name}\t#{?#{==:#{@pi_status},busy},Working,Ready}\t(window #{window_index}, pane #{pane_index})')

if [[ -z "$candidates" ]]; then
	printf '%s\n' 'No Pi panes found.' >&2
	exit 0
fi

if selected=$(printf '%s\n' "$candidates" | fzf \
	--no-multi \
	--delimiter=$'\t' \
	--with-nth=2.. \
	--preview='tmux capture-pane -p -e -t {1} -S -80' \
	--preview-window='right,65%,wrap,follow' \
	--prompt='Pi conversation> '); then
	target=${selected%%$'\t'*}
else
	status=$?
	# No match and cancellation are normal exits, not errors.
	case "$status" in
		1|130) exit 0 ;;
		*) exit "$status" ;;
	esac
fi

[[ -n "$target" ]] || exit 0

# Session-qualified IDs also disambiguate windows linked into multiple sessions.
if [[ -n "${TMUX:-}" ]]; then
	# A pane target switches the session, window, and active pane together.
	exec tmux switch-client -t "$target"
else
	tmux select-window -t "$target"
	tmux select-pane -t "$target"
	exec tmux attach-session -t "$target"
fi
