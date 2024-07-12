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

function install_pkg {
	if command -v dnf; then
		sudo dnf install $1
	elif command -v brew; then
		brew install $1
	else
		echo "could not find package manager to install $1"
		exit 1
	fi
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

# TODO setup GPG so I don't have to generate and manage a key on every machine
function setup_ssh {
	# make sure dir exists before calling stow so stow doesn't manage it entirely
	mkdir -p ~/.ssh
	stow ssh -t $HOME
}

function setup_docker {
	case $OSTYPE in
		darwin*)
			brew install orbstack
			;;
		linux*)
			if command -v dnf; then
				sudo dnf -y install dnf-plugins-core
				sudo dnf config-manager \
					--add-repo \
					https://download.docker.com/linux/fedora/docker-ce.repo
				sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
			else
				echo "Don't know how to setup docker in this distro"
				exit 1
			fi

			usermod -a -G docker $USER
			echo 'Docker installed successfully. Re-login or run `sudo su $USER` to start a session with the required groups'
			;;
	esac
	
}

function setup_asdf {
	rm -rf $HOME/.local/asdf || true
	git clone https://github.com/asdf-vm/asdf.git $HOME/.local/asdf --branch v0.14.0
	stow asdf -t $HOME
}

function setup_tmux {
	install_pkg tmux
	stow tmux -t $HOME
}

function setup_nvim {
	install_pkg neovim ripgrep
	stow nvim -t $HOME
}

function setup_direnv {
	install_pkg direnv
	stow direnv -t $HOME
}

function setup_elixir {
	erlang_version=27.0
	elixir_version=17.2-otp-27

	# see https://github.com/asdf-vm/asdf-erlang?tab=readme-ov-file#before-asdf-install
	case $OSTYPE in
		linux-gnu*)
			sudo dnf group install -y 'Development Tools' 'C Development Tools and Libraries'
			sudo dnf install -y openssl-devel automake autoconf ncurses-devel g++ busybox wxGTK-devel
			;;
		darwin*)
			brew install autoconf openssl wxwidgets libxslt fop wxmac
			;;
		*)
			echo "Unknown OS - can't install Erlang/Elixir dependencies"
	esac

	. $HOME/.asdf/asdf.sh

	asdf plugin-add erlang https://github.com/asdf-vm/asdf-erlang.git || true
	asdf install erlang ${erlang_version}
	asdf global erlang ${erlang_version}

	asdf plugin-add elixir || true
	asdf install elixir ${elixir_version}
	asdf global elixir ${elixir_version}
}

function setup_elixir_ls {
	elixir_ls_version=0.22.1

	rm -rf ~/.local/elixir-ls || true
	mkdir -p ~/.local/elixir-ls
	pushd  ~/.local/elixir-ls
	curl -fsSL https://github.com/elixir-lsp/elixir-ls/releases/download/v${elixir_ls_version}/elixir-ls-v${elixir_ls_version}.zip > /tmp/elixir-ls.zip
	unzip /tmp/elixir-ls.zip
	chmod +x language_server.sh launch.sh
	popd
}

function setup_git {
	install_pkg git-lfs

	stow git -t $HOME
}

case $OSTYPE in
	darwin*)
		command -v brew || {
			curl -fsSL https://github.com/Homebrew/brew/releases/download/4.3.9/Homebrew-4.3.9.pkg -o /tmp/homebrew.pkg
			open /tmp/homebrew.pkg
		}
		;;
esac


command -v stow || install_pkg stow



case ${1:-basic} in
	zsh)
		setup_zsh
		;;
	asdf)
		setup_asdf
		;;
	direnv)
		setup_direnv	
		;;
	git)
		setup_git
		;;
	tmux)
		setup_tmux
		;;
	nvim)
		setup_nvim
		;;
	elixir)
		setup_elixir
		setup_elixir_ls
		;;
	elixir_ls)
		setup_elixir_ls
		;;
	docker)
		setup_docker
		;;
	ssh)
		setup_ssh
		;;
	basic)
		setup_zsh
		setup_ssh
		setup_asdf
		setup_tmux
		setup_nvim
		setup_direnv
		setup_docker
		;;
esac
