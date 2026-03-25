#!/usr/bin/env bash

set -euo pipefail

DMUX_DIR="${DMUX_DIR:-.dmux/worktrees}"

if [[ ! -d "$DMUX_DIR" ]]; then
	echo "No dmux worktrees found in $DMUX_DIR"
	exit 1
fi

worktree=$(fd -t d -d 1 . "$DMUX_DIR" | fzf --prompt="review worktree> ")

[[ -z "$worktree" ]] && exit 0

tmux new-window -c "$worktree" nvim
