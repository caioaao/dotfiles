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
	just stow herdr true
	just stow direnv true
	just stow mise true
	just stow claude-code true
	just bootstrap-pi
	just bootstrap-omp
	just setup-dev-secrets

bootstrap-pi:
	mkdir -p $HOME/.pi/agent/{skills,extensions/subagent,prompts}
	just stow pi true 

bootstrap-omp: xdg-base-dirs
	# PI_CONFIG_DIR relocates omp's config root to ~/.config/omp; pre-create the
	# agent dir so stow links files individually instead of symlinking the whole
	# directory (omp writes config.yml.lock next to config.yml).
	mkdir -p $HOME/.config/omp/agent
	# omp only splits runtime state (DBs, sessions, logs, caches) out of the
	# config root when these already exist; otherwise it writes them next to
	# config.yml. See docs: config-usage.md -> Profiles.
	mkdir -p $XDG_DATA_HOME/omp $XDG_STATE_HOME/omp $XDG_CACHE_HOME/omp
	just stow omp true

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
