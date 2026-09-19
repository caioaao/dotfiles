#!/usr/bin/env bash

set -euo pipefail

export PROJECTS_DIR="${PROJECTS_DIR:-$HOME/reps}"

function select_path {
	local path
	path="$(realpath "$1")" || return
	echo "${path#"$PROJECTS_DIR/"}"
}

function fzf_project {
	local project
	project="$(fd -H -I -t f -t d -d 4 '^\.git$' "${PROJECTS_DIR}" --exec dirname | sort -u | fzf)" || return
	[[ -n "$project" ]] || return 1
	select_path "$project"
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

function usage_error {
	printf '%s\n' "$1" 'Usage: tms [-d] [--new | --sessions] [--] [project]' >&2
	exit 2
}

detached=false
mode=''
operands=()
while (( $# > 0 )); do
	case "$1" in
		-d)
			detached=true
			;;
		--new|--sessions)
			[[ -z "$mode" ]] || usage_error 'Select only one of --new or --sessions.'
			mode=$1
			;;
		--)
			shift
			operands+=("$@")
			break
			;;
		-*)
			usage_error "Unknown option: $1"
			;;
		*)
			operands+=("$1")
			;;
	esac
	shift
done
(( ${#operands[@]} <= 1 )) || usage_error 'Expected at most one project.'

case "$mode" in
	--new)
		selected="${operands[0]:-$(fzf_project)}"
		;;
	--sessions)
		selected="${operands[0]:-$(fzf_session)}"
		;;
	*)
		if (( ${#operands[@]} > 0 )); then
			selected=$(select_path "${operands[0]}")
		else
			selected=$(fzf_session)
		fi
		;;
esac

[[ -z "$selected"  ]] && {
	echo 'No project selected. Exiting' >&2
	exit 1
}

session_name=${selected//\./__}

tmux has-session -t "=$session_name" 2>/dev/null || {
	path=$PROJECTS_DIR/$selected
	tmux new -d -c "$path" -s "$session_name" nvim
	tmux new-window -t "=$session_name:" -c "$path" -d
}

if "$detached"; then
	printf '%s\n' "$session_name"
elif [ -z "${TMUX:-}" ]; then
	tmux attach -t "=$session_name"
else
	tmux switch-client -t "=$session_name"
fi
