#!/usr/bin/env bash

function code {
	tmux new -A -c ~/reps/$1 -s $1
}
