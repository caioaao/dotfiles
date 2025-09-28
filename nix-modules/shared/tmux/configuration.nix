{ pkgs, ... }: {
  
  environment.systemPackages = with pkgs.tmuxPlugins; [
      catppuccin
      fzf-tmux-url
      resurrect
     (pkgs.writeShellApplication {
       name = "tms";
       runtimeInputs = [
         pkgs.coreutils
         pkgs.fzf
         pkgs.tmux
       ];
       text = builtins.readFile ./tms.sh; # keep your script in a file
     })
  ];
  
  programs.tmux = {
    enable = true;
    extraConfig = ''
            # Change prefix to C-q
            unbind-key C-b
            set -g prefix 'C-q'
            bind-key 'C-q' send-prefix

            # reload config
            bind r source-file /etc/tmux.conf

            # Enable clipboard passthrough
            set -g set-clipboard on
            set -g allow-passthrough on

            # Enable mouse support
            set -g mouse on

            # don't really remember
            set-option -gw aggressive-resize on

            # Remove delay when pressing esc
            set-option -s escape-time 50

            # Enable focus events for Neovim
            set -g focus-events on

            # Split windows (similar to nvim)
            bind v split-window -h
            bind s split-window -v
            unbind '"'
            unbind %

            # Move between panes with vim movement keys
            bind h select-pane -L
            bind j select-pane -D
            bind k select-pane -U
            bind l select-pane -R

            unbind o

            # Session management
            bind W display-popup -E "tms --new"
            bind w display-popup -E "tms --sessions"

            # Window cycling
            bind H previous-window
            bind L next-window

            # Copy mode
            bind-key -T copy-mode-vi v send -X begin-selection
            bind-key -T copy-mode-vi V send -X select-line
            bind-key -T copy-mode-vi y send -X copy-pipe-and-cancel 'xclip -in -selection clipboard'

            # Other stuff
            set-option -g history-limit 5000
            set -g mode-keys vi

            # Plugins
            set -g @catppuccin_window_status_style "rounded"
            set -g @catppuccin_flavor "latte"

            # Make sure the window names are properly rendered (https://github.com/catppuccin/tmux/issues/431)
            set -g @catppuccin_window_text "#W"
            set -g @catppuccin_window_current_text " #W"

            run-shell ${pkgs.tmuxPlugins.catppuccin}/share/tmux/plugins/catppuccin/catppuccin.tmux
            run-shell ${pkgs.tmuxPlugins.fzf-tmux-url}/share/tmux/plugins/fzf-tmux-url/fzf-tmux-url.tmux
            run-shell ${pkgs.tmuxPlugins.resurrect}/share/tmux/plugins/resurrect/resurrect.tmux
    '';
  };
}
