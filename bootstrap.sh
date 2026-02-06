#!/usr/bin/env bash

set -euxo pipefail

function log_info {
	echo -e "\033[1;34m[INFO]\033[0m $*"
}

### Setup Nix
function setup_darwin {
	log_info "darwin OS detected..."

	if ! command -v nix; then
		log_info "Installing Nix..."
		curl -fsSL https://install.determinate.systems/nix | sh -s -- install

		log_info "Enabling Nix..."
		if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
			. "$HOME/.nix-profile/etc/profile.d/nix.sh"
		elif [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
			. "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
		elif [ -f "/etc/profile.d/nix.sh" ]; then
			. "/etc/profile.d/nix.sh"
		fi
	fi

	log_info "Nix installed successfully"

	log_info "Setting up nix-darwin and installing config..."
	sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake github:caioaao/dotfiles#darwin
}

function setup_nixos {
	log_info "NixOS detected. Installing config..."
	sudo nixos-rebuild switch --flake github:caioaao/dotfiles#nixos
}

[[ $OSTYPE == 'darwin'* ]] && setup_darwin
[[ command -v nixos-rebuild ]] && setup_nixos

### Clone repo

log_info "Cloning dotfiles..."
mkdir -p $HOME/reps/caioaao
cd $HOME/reps/caioaao
git clone https://github.com/caioaao/dotfiles.git $HOME/reps/caioaao || true

log_info "Bootstrapping config..."
pushd $HOME/reps/caioaao/dotfiles
just bootstrap
popd

