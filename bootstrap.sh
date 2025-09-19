#!/usr/bin/env bash

function log_info {
  echo -e "\033[1;34m[INFO]\033[0m $*"
}

### Setup Nix

if !command -v nix; then

	log_info "Installing Nix"
	sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon
	. $HOME/.nix-profile/etc/profile.d/nix.sh

	log_info "Configuring Nix..."

	nix_config_dir=$HOME/.config/nix
	mkdir -p $nix_config_dir
	log_info 'experimental-features = nix-command flakes' > $nix_config_dir/nix.conf
fi

log_info "Installing base package..."

nix profile add github:caioaao/dotfiles/nix-2025#base

log_info "Nix setup successfully"

### Clone repo

log_info "Cloning dotfiles..."
mkdir -p $HOME/reps/caioaao
cd $HOME/reps/caioaao
git clone https://github.com/caioaao/dotfiles.git $HOME/reps/caioaao || true

pushd $HOME/reps/caioaao/dotfiles
just bootstrap
popd

