#!/usr/bin/env bash

set -euxo pipefail

function log_info {
	echo -e "\033[1;34m[INFO]\033[0m $*"
}

### Setup Nix
function setup_darwin {
	log_info "darwin OS detected..."

	if !command -v nix; then
		log_info "Installing Nix..."
		sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon
		. $HOME/.nix-profile/etc/profile.d/nix.sh

		log_info "Configuring Nix..."

		nix_config_dir=$HOME/.config/nix
		mkdir -p $nix_config_dir
		echo 'experimental-features = nix-command flakes' > $nix_config_dir/nix.conf
	fi

	log_info "Nix installed successfully"

	log_info "Installing nix-darwin..."
	sudo nix run nix-darwin/master#darwin-rebuild -- switch
	log_info "nix-darwin set up"

	log_info "Installing config"
	sudo darwin-rebuild switch --flake github:caioaao/nix-config#darwin
}

function setup_nixos {
	log_info "NixOS detected. Installing config..."
	sudo nixos-rebuild switch --flake github:caioaao/nix-config#nixos
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

