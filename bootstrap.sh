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
	local flake_config="${1:-nixos}"
	log_info "NixOS detected. Installing config '${flake_config}'..."
	sudo nixos-rebuild switch --flake "github:caioaao/dotfiles#${flake_config}"
}

if [[ $OSTYPE == 'darwin'* ]]; then
	setup_darwin
elif command -v nixos-rebuild &>/dev/null; then
	setup_nixos "${NIXOS_FLAKE_CONFIG:-nixos}"
fi

### Clone repo

log_info "Cloning dotfiles..."
mkdir -p $HOME/reps/caioaao
cd $HOME/reps/caioaao
git clone https://github.com/caioaao/dotfiles.git $HOME/reps/caioaao || true

log_info "Bootstrapping config..."
pushd $HOME/reps/caioaao/dotfiles
just bootstrap
popd

