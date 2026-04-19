export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

for f in $(find -L $XDG_CONFIG_HOME/zsh/zshenv.d/ -type f 2>/dev/null | sort); do
  source $f
done
