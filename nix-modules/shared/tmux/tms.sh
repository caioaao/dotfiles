#!/usr/bin/env bash

set -euo pipefail

export PROJECTS_DIR="${PROJECTS_DIR:-$HOME/reps}"

function select_path {
	local path
	path="$(realpath "$1")"
	echo "${path#"$PROJECTS_DIR/"}"
}

function fzf_project {
	select_path "$(find "${PROJECTS_DIR}" -iname .git -type d -maxdepth 3 -print0 | xargs -0 dirname | fzf)"
}

function fzf_session {
	local candidates
	candidates=$(tmux list-sessions -F '#{session_attached} #{session_last_attached} #{session_name}' | grep '^0 ' | sort -rn | cut -d' ' -f3-)
	if [[ -z "$candidates" ]]; then
		fzf_project
	else
		echo "$candidates" | fzf
	fi
}


case "${1:-}" in
	--new)
		selected="${2:-$(fzf_project)}"
		;;
	--sessions|'')
		selected="${2:-$(fzf_session)}"
		;;
	*)
		selected=$(select_path "$1")
		;;
esac

[[ -z "$selected"  ]] && {
	echo 'No project selected. Exiting'
	exit 1
}

session_name=${selected//\./__}

tmux has-session -t "$session_name" || {
	path=$PROJECTS_DIR/$selected
	tmux new -d -c "$path" -s "$session_name" nvim
	tmux new-window -c "$path" -d
}

if [ -z "${TMUX:-}" ]; then
	tmux attach -t "$session_name"
else
	tmux switch-client -t "$session_name"
fi
