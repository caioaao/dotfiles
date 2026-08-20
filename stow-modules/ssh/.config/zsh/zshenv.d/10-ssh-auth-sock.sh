# Workaround to avoid having to fix the auth socket on herdr/tmux
# Issue: https://github.com/herdrdev/herdr/issues/1931 

if [ -n "$SSH_AUTH_SOCK" ] \
   && [ -S "$SSH_AUTH_SOCK" ] \
   && [ "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent.sock" ]; then
  ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/agent.sock"
fi
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
