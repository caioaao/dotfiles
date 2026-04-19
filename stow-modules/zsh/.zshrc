export ZSH=$HOME/.nix-profile/share/oh-my-zsh

plugins=(
	common-aliases
	git
)

for f in $(find -L $XDG_CONFIG_HOME/zsh/zshrc.d/ -type f 2>/dev/null | sort); do
	source $f
done
