{ pkgs, ... }: {
  environment.systemPackages = with pkgs.tmuxPlugins; [
    # Tmux plugins
    catppuccin
    fzf-tmux-url
    resurrect

    # Custom tmux session manager script
    (pkgs.writeShellApplication {
      name = "tms";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.fzf
        pkgs.tmux
      ];
      text = builtins.readFile ./tms.sh;
    })
  ];

  programs.tmux = {
    enable = true;
    extraConfig = ''
      # ===============================
      # Prefix Key Configuration
      # ===============================
      unbind-key C-b
      set -g prefix 'C-q'
      bind-key 'C-q' send-prefix

      # ===============================
      # System and Performance
      # ===============================
      # Reload tmux configuration
      bind r source-file /etc/tmux.conf

      # Enable clipboard passthrough and mouse support
      set -g set-clipboard on
      set -g allow-passthrough on
      set -g mouse on

      # Optimize for terminal resizing
      set-option -gw aggressive-resize on

      # Remove delay when pressing escape (improves vim experience)
      set-option -s escape-time 50

      # Enable focus events for Neovim integration
      set -g focus-events on

      # History and input settings
      set-option -g history-limit 5000
      set -g mode-keys vi

      # ===============================
      # Pane and Window Management
      # ===============================
      # Split windows with vim-like keys
      bind v split-window -h
      bind s split-window -v
      unbind '"'
      unbind %

      # Navigate panes with vim movement keys
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      unbind o

      # Window cycling
      bind H previous-window
      bind L next-window

      # ===============================
      # Session Management (TMS)
      # ===============================
      bind W display-popup -E "tms --new"
      bind w display-popup -E "tms --sessions"

      # ===============================
      # Copy Mode Configuration
      # ===============================
      bind-key -T copy-mode-vi v send -X begin-selection
      bind-key -T copy-mode-vi V send -X select-line
      bind-key -T copy-mode-vi y send -X copy-pipe-and-cancel 'xclip -in -selection clipboard'

      # ===============================
      # Theme Configuration (Catppuccin)
      # ===============================
      set -g @catppuccin_flavor "mocha"
      set -g @catppuccin_window_status_style "rounded"

      # Window name rendering fix
      # See: https://github.com/catppuccin/tmux/issues/431
      set -g @catppuccin_window_text "#W"
      set -g @catppuccin_window_current_text " #W"

      # ===============================
      # Plugin Initialization
      # ===============================
      run-shell ${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin/catppuccin.tmux
      run-shell ${pkgs.tmuxPlugins.fzf-tmux-url}/share/tmux-plugins/fzf-tmux-url/fzf-url.tmux
      run-shell ${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/resurrect.tmux
    '';
  };
}
