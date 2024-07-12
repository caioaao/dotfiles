#!/usr/bin/env bash

### TODO use configure/make

set -euox pipefail

export DOTFILES_DIR=$(dirname "$0")
export STOW_DIR="$DOTFILES_DIR"/modules


function backup {
	for f in "$@"; do
		mv "$f" "$f.`date +%s`" || true
	done
}

function setup_zsh {
	echo 'Installing oh-my-zsh'
	rm -rf $HOME/.local/oh-my-zsh || true
	git clone https://github.com/ohmyzsh/ohmyzsh.git $HOME/.local/oh-my-zsh

	echo 'installing zoxide'
	curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

	echo 'installing fzf'
	rm -rf $HOME/.local/fzf || true
	git clone --depth 1 https://github.com/junegunn/fzf.git $HOME/.local/fzf
	$HOME/.local/fzf/install --xdg --key-bindings --completion --no-update-rc

	stow zsh -t $HOME
}

function setup_asdf {
	rm -rf $HOME/.local/asdf || true
	git clone https://github.com/asdf-vm/asdf.git $HOME/.local/asdf --branch v0.14.0
	stow asdf -t $HOME
}

case ${1:-basic} in
	zsh)
		setup_zsh
		;;
	asdf)
		setup_asdf
		;;
	basic)
		setup_zsh
		setup_asdf
esac
