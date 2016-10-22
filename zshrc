source $HOME/.zshrc.setup

source $dotfiles_path/antigen/antigen.zsh

# Load the oh-my-zsh's library.
antigen use oh-my-zsh

# Bundles from the default repo (robbyrussell's oh-my-zsh).
antigen bundle git
antigen bundle heroku
antigen bundle pip
antigen bundle lein
antigen bundle command-not-found
antigen bundle autojump
antigen bundle emacs
antigen bundle archlinux
antigen bundle common-aliases

# Syntax highlighting bundle.
antigen bundle zsh-users/zsh-syntax-highlighting

# autocomplete
# antigen bundle zsh-users/zsh-completions src

# Load the theme.
antigen theme gallois

# Tell antigen that you're done.
antigen apply

# Other stuff
export PATH=$HOME/anaconda2/bin:$PATH

# Import local dotfile
source ~/.localrc

