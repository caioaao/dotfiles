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


read -rp $'Symlink Xresources? ([y]/n)\n' SYM_XRESOURCES
if [[ "$SYM_XRESOURCES" == "n" ]]; then
    echo "skipping Xresources"
else
    echo "Symlinking Xresources"
    ln -s $dotfiles_path/xconf/Xresources $HOME/.Xresources
fi


echo "Symlinking utils"

read -rp $'Symlink lein profiles.clj? ([y]/n)\n' SYM_LEIN_PROFILES
if [[ "$SYM_LEIN_PROFILES" == "n" ]]; then
    echo "skipping lein profiles.clj"
else
    mkdir -p $HOME/.lein
    ln -s ${dotfiles_path}/utils/lein/profiles.clj ${HOME}/.lein/profiles.clj
fi

read -rp $'Symlink global gitignore? ([y]/n)\n' SYM_GITIGNORE
if [[ "$SYM_GITIGNORE" == "n" ]]; then
    echo "skipping gitignore"
else
    ln -s ${dotfiles_path}/utils/git/gitignore_global ${HOME}/.gitignore_global
fi

echo "Done. Please restart the terminal."
