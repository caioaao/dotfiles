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
		sudo dnf install $@
	elif command -v brew; then
		brew install $@
	else
		echo "could not find package manager to install $1"
		exit 1
	fi
}

function setup_xdg_base_dirs {
	export XDG_DATA_HOME=$HOME/.local/share
	export XDG_STATE_HOME=$HOME/.local/state
	export XDG_CONFIG_HOME=$HOME/.config
	export XDG_CACHE_HOME=$HOME/.cache

	mkdir -p $XDG_DATA_HOME
	mkdir -p $XDG_STATE_HOME
	mkdir -p $XDG_CONFIG_HOME
	mkdir -p $XDG_CACHE_HOME

	mkdir -p $HOME/.local/bin
}

function setup_zsh {
	echo 'Installing oh-my-zsh'
	rm -rf $XDG_DATA_HOME/oh-my-zsh || true
	git clone https://github.com/ohmyzsh/ohmyzsh.git $XDG_DATA_HOME/oh-my-zsh

	echo 'installing zoxide'
	curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

	echo 'installing fzf'
	rm -rf $XDG_DATA_HOME/fzf || true
	git clone --depth 1 https://github.com/junegunn/fzf.git $XDG_DATA_HOME/fzf
	$XDG_DATA_HOME/fzf/install --xdg --key-bindings --completion --no-update-rc

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

function setup_zig {
	case $OSTYPE in
		linux*)
			platform=linux-x86_64
			;;
		darwin*)
			platform=macos-aarch64
			;;
		*)
			echo "TODO ${OSTYPE}"
			exit 1
			;;
	esac

	pushd /tmp
	curl -LO https://ziglang.org/download/0.13.0/zig-${platform}-0.13.0.tar.xz
	sudo rm -rf /opt/zig
	sudo tar -C /opt -xf zig-${platform}-0.13.0.tar.xz
	echo "PATH=/opt/zig-${platform}-0.13.0:\$PATH" > ~/.config/zsh.d/10-zig.sh

}

function setup_ghostty {
	which zig || setup_zig
	stow ghostty -t $HOME
	case $OSTYPE in
		linux*)
			repo_dir=$HOME/reps/mitchellh/ghostty
			mkdir -p $repo_dir
			# ghostty is private, so we need to setup github auth before
			git clone git@github.com:mitchellh/ghostty.git $repo_dir || true
			pushd $repo_dir
			zig build -p $HOME/.local -Doptimize=ReleaseFast
			# remove desktop entry in favor of our own
			rm -f $XDG_DATA_HOME/applications/com.mitchellh.ghostty.desktop
			popd
			stow ghostty_linux -t $HOME
			;;
		darwin*)
			echo "TODO - download the binary instead"
			exit 1
			;;
	esac
}

# A fancy shell prompt. starship.rs
function setup_starship {
	curl -sS https://starship.rs/install.sh | sh
	stow starship -t $HOME
}

function setup_asdf {
	rm -rf $XDG_DATA_HOME/.asdf || true
	git clone https://github.com/asdf-vm/asdf.git $XDG_DATA_HOME/asdf --branch v0.14.0
	stow asdf -t $HOME
}

function setup_mise {
	curl https://mise.run | sh
	stow mise -t $HOME 
}

function setup_tmux {
	install_pkg pkg-config
	install_pkg utf8proc

	git clone https://github.com/tmux/tmux.git /tmp/tmux

	pushd /tmp/tmux
	sh autogen.sh
	./configure --enable-utf8proc
	make
	sudo make install
	popd
	rm -rf /tmp/tmux

	stow tmux -t $HOME
}

function setup_tmux_tpm {
	rm -rf $XDG_DATA_HOME/tmux/plugins || true
	mkdir -p $XDG_DATA_HOME/tmux/plugins

	git clone https://github.com/tmux-plugins/tpm $XDG_DATA_HOME/tmux/plugins/tpm

	$XDG_DATA_HOME/tmux/plugins/tpm/bin/install_plugins
	stow tmux_tpm -t $HOME
}

function setup_nvim {
	install_pkg ripgrep wget fd
	case $OSTYPE in 
		linux*)
			echo 'installing neovim'
			pushd /tmp
			curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
			sudo rm -rf /opt/nvim
			sudo tar -C /opt -xzf nvim-linux64.tar.gz
			popd
			;;
		*) 
			install_pkg neovim
			;;
	esac
	# install vscode langservers for html LSP
	npm i -g vscode-langservers-extracted
	stow nvim -t $HOME
}

function setup_direnv {
	install_pkg direnv
	stow direnv -t $HOME
}

function setup_elixir {
	erlang_version=27.2
	elixir_version=1.18.2

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

	mise use --global erlang@${erlang_version}
	mise use --global elixir@${elixir_version}

	stow elixir -t $HOME
}

function setup_elixir_ls {
	elixir_ls_version=0.27.2

	rm -rf $XDG_DATA_HOME/elixir-ls || true
	mkdir -p $XDG_DATA_HOME/elixir-ls
	pushd  $XDG_DATA_HOME/elixir-ls
	curl -fsSL https://github.com/elixir-lsp/elixir-ls/releases/download/v${elixir_ls_version}/elixir-ls-v${elixir_ls_version}.zip > /tmp/elixir-ls.zip
	unzip /tmp/elixir-ls.zip
	chmod +x language_server.sh launch.sh
	popd
}

function setup_git {
	install_pkg git-lfs

	stow git -t $HOME
}

# https://abhinav.github.io/git-spice
function setup_git_spice {
	mise use --global 'ubi:abhinav/git-spice[exe=gs]'
	stow git_spice -t $HOME

}

function setup_homebrew {
	curl -fsSL https://github.com/Homebrew/brew/releases/download/4.3.9/Homebrew-4.3.9.pkg -o /tmp/homebrew.pkg
	open /tmp/homebrew.pkg
	stow brew -t $HOME
}

function setup_keymapp {
	local tmp_dir
	tmp_dir=`mktemp -d`

	curl -fsSL https://oryx.nyc3.cdn.digitaloceanspaces.com/keymapp/keymapp-latest.tar.gz | tar -xz -C $tmp_dir
	mv $tmp_dir/keymapp $HOME/.local/bin
	mkdir -p $XDG_DATA_HOME/icons/hicolor/scalable/apps
	mv $tmp_dir/icon.png $XDG_DATA_HOME/icons/hicolor/scalable/apps/keymapp.png
	stow keymapp -t $HOME
}

function setup_rust {
	rust_version=1.77.2
	mise use --global rust@${rust_version}
}

function setup_nodejs {
	local global_version
	global_version=23.8.0

	mise use --global nodejs@$global_version
}

function setup_ffmpeg {
	install_pkg ffmpeg
	stow ffmpeg -t $HOME
}


[[ -d $XDG_DATA_HOME ]] || setup_xdg_base_dirs

case $OSTYPE in
	darwin*)
		command -v brew || setup_homebrew
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
	git_spice)
		setup_git_spice
		;;
	homebrew)
		setup_homebrew
		;;
	tmux)
		setup_tmux
		setup_tmux_tpm
		;;
	tmux_tpm)
		setup_tmux_tpm
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
	ghostty)
		setup_ghostty
		;;
	nodejs)
		setup_nodejs
		;;
	ffmpeg)
		setup_ffmpeg
		;;
	rust)
		setup_rust
		;;
	ssh)
		setup_ssh
		;;
	keymapp)
		setup_keymapp
		;;
	zig)
		setup_zig
		;;
	mise)
		setup_mise
		;;
	starship)
		setup_starship
		;;
	basic)
		setup_zsh
	#	setup_ssh
		setup_mise
		setup_tmux
		setup_tmux_tpm
		setup_nvim
		setup_direnv
		setup_docker
		;;
	*)
		echo "Command not found"
		exit 1
esac
