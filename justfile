export XDG_DATA_HOME := x'${HOME}/.local/share'
export XDG_STATE_HOME := x'${HOME}/.local/state'
export XDG_CONFIG_HOME := x'${HOME}/.config'
export XDG_CACHE_HOME := x'${HOME}/.cache'
export USER_BIN_DIR := x'${HOME}/.local/bin'

bootstrap: xdg-base-dirs
	# make sure dir exists before calling stow so stow doesn't manage it entirely
	mkdir -p $HOME/.ssh

	just stow zsh
	just stow ssh
	just stow direnv
	just stow nvim
	just stow tmux
	just stow ghostty

	chsh -s $(which zsh)

stow module: xdg-base-dirs
	stow -t $HOME -d {{ justfile_directory() }}/modules {{ module }}

xdg-base-dirs:
	mkdir -p $XDG_DATA_HOME
	mkdir -p $XDG_STATE_HOME
	mkdir -p $XDG_CONFIG_HOME
	mkdir -p $XDG_CACHE_HOME
	mkdir -p $HOME/.local/bin
