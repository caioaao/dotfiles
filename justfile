export XDG_DATA_HOME := x'${HOME}/.local/share'
export XDG_STATE_HOME := x'${HOME}/.local/state'
export XDG_CONFIG_HOME := x'${HOME}/.config'
export XDG_CACHE_HOME := x'${HOME}/.cache'
export USER_BIN_DIR := x'${HOME}/.local/bin'

bootstrap:
	# make sure dir exists before calling stow so stow doesn't manage it entirely
	mkdir -p $HOME/.ssh

	just stow git adopt=true
	just stow zsh adopt=true
	just stow ssh adopt=true
	just stow direnv adopt=true
	just stow nvim adopt=true
	just stow ghostty adopt=true
	just stow mise adopt=true

stow module adopt="false": xdg-base-dirs
	#!/usr/bin/env bash
	set -euox pipefail
	if [ "{{ adopt }}" = "true" ]; then 
		extra="--adopt"
	else
		extra=""
	fi
	stow ${extra} -t $HOME -d {{ justfile_directory() }}/stow-modules {{ module }}

xdg-base-dirs:
	mkdir -p $XDG_DATA_HOME
	mkdir -p $XDG_STATE_HOME
	mkdir -p $XDG_CONFIG_HOME
	mkdir -p $XDG_CACHE_HOME
	mkdir -p $HOME/.local/bin
