export CAIOAAO_REPS_PATH=$HOME/reps
#
# use XDG Base Directory spec: https://wiki.archlinux.org/title/XDG_Base_Directory
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache

export PATH=$PATH:$HOME/.local/bin
export MY_ZSH_CONFIG=$XDG_CONFIG_HOME/zsh.d

mkdir -p $MY_ZSH_CONFIG

export ZSH=$HOME/.local/oh-my-zsh


plugins=(
	common-aliases
	git
)

ZSH_THEME="gallois"

for f in `find -L $MY_ZSH_CONFIG/ -type f | sort`; do
	source $f
done

