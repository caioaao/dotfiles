export XDG_DATA_HOME := x'${HOME}/.local/share'
export XDG_STATE_HOME := x'${HOME}/.local/state'
export XDG_CONFIG_HOME := x'${HOME}/.config'
export XDG_CACHE_HOME := x'${HOME}/.cache'
export USER_BIN_DIR := x'${HOME}/.local/bin'

bootstrap:
	# make sure dir exists before calling stow so stow doesn't manage it entirely
	mkdir -p $HOME/.ssh

	just stow git true
	just stow git_spice true
	just stow zsh true
	just stow ssh true
	just stow nvim true
	just stow ghostty true
	just stow direnv true
	just stow mise true
	just stow claude-code true
	just bootstrap-pi
	just setup-dev-secrets

bootstrap-pi:
	mkdir -p $HOME/.pi/agent/{skills,extensions/subagent,prompts}
	just stow pi true 

stow module adopt="false": xdg-base-dirs
	#!/usr/bin/env bash
	set -euox pipefail
	if [ "{{ adopt }}" = "true" ]; then 
		extra="--adopt"
	else
		extra=""
	fi
	stow ${extra} -t $HOME -d {{ justfile_directory() }}/stow-modules {{ module }}

setup-dev-secrets:
	op item get dev-secrets --fields notesPlain --account my.1password.com > $XDG_CONFIG_HOME/zsh/zshenv.d/10-secrets.sh

[linux]
enroll-fingerprint:
	fprintd-enroll

xdg-base-dirs:
	mkdir -p $XDG_DATA_HOME
	mkdir -p $XDG_STATE_HOME
	mkdir -p $XDG_CONFIG_HOME
	mkdir -p $XDG_CACHE_HOME
	mkdir -p $HOME/.local/bin
