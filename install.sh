#!/bin/bash

# Script to install dotfiles in a new environment

set -u
set -e

zsh_path="/bin/zsh"
read -rp "Path to zsh (default: '/bin/zsh'): " zsh_path
chsh -s /bin/zsh

echo 'Cloning submodules'
git submodule init
git submodule update

dotfiles_path="$(pwd)"

touch $HOME/.localrc
echo 'Put local config inside ".localrc" (work stuff, for instance)'

echo "Creating zshrc setup file in $HOME/.zshrc.setup"
echo "dotfiles_path=$dotfiles_path" > $HOME/.zshrc.setup

echo "Symlinking zshrc file"
ln -s $dotfiles_path/zshrc $HOME/.zshrc

echo "Done. Please restart the terminal."
