REPS_PATH=~/reps

export PATH=$PATH:$HOME/.local/bin
export MY_ZSH_CONFIG=$HOME/.config/zsh.d

mkdir -p $MY_ZSH_CONFIG

# omz
ZSH=$HOME/.local/oh-my-zsh

plugins=(
	common-aliases
	git
)

ZSH_THEME="gallois"

for f in `find $MY_ZSH_CONFIG/ -type f | sort`; do
	source $f
done

