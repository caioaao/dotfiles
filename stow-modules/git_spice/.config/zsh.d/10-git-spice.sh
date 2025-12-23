# I was getting errors saying compinit was not found. This line fixed it
autoload -U +X compinit && compinit

eval "$(gs shell completion zsh)"

# Git-spice aliases for common commands

# Repository operations
alias gss='gs repo sync'

# Branch navigation
alias gsu='gs up'
alias gsd='gs down'
alias gst='gs top'
alias gsb='gs bottom'
alias gstrunk='gs trunk'

# Branch operations
alias gsco='gs b checkout'
alias gsc='gs b create'
gscm() { gs b create --target main "$@"; }
alias gsub='gs b submit'
alias gsr='gs b restack'
alias gsrm='gs b delete'
alias gsmv='gs b rename'

# Stack operations
alias gssr='gs s restack'
alias gsse='gs s edit'

# Rebase operations
alias gsrc='gs rebase continue'
alias gsra='gs rebase abort'

# Log operations
alias gsl='gs log short'
alias gsll='gs log long'
