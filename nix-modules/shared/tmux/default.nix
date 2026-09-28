{ pkgs, ... }: {
  environment.systemPackages = with pkgs.tmuxPlugins; [
    # Tmux plugins
    catppuccin
    fzf-tmux-url

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

    # Jump to an agent pane in the current tmux session
    (pkgs.writeShellApplication {
      name = "tmux-agent-panes";
      runtimeInputs = [
        pkgs.fzf
        pkgs.tmux
      ];
      text = builtins.readFile ./tmux-agent-panes.sh;
    })

    # Animate the working-agent indicator in the window pill
    (pkgs.writeShellApplication {
      name = "tmux-agent-spinner";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.tmux
        pkgs.util-linux
      ];
      text = builtins.readFile ./tmux-agent-spinner.sh;
    })

  ];

  programs.tmux = {
    enable = true;
    extraConfig = ''
      set -g default-terminal "tmux-256color"
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
      bind r source-file /etc/tmux.conf \; display-message "Config reloaded"

      # Enable clipboard passthrough and mouse support
      set -g set-clipboard on
      set -g allow-passthrough on
      set -g mouse on

      # Allow programs to rename the window via escape sequences
      set -g allow-rename on

      # Forward tmux session name to the host terminal (Ghostty tab title)
      set -g set-titles on
      set -g set-titles-string '#{s/__/./:session_name}'

      # Optimize for terminal resizing
      set-option -gw aggressive-resize on

      # Remove delay when pressing escape (improves vim experience)
      set-option -s escape-time 50

      # Enable focus events for Neovim integration
      set -g focus-events on

      # History and input settings
      set-option -g history-limit 50000
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

      # Start window and pane numbering at 1 (0 is far from the other digits)
      set -g base-index 1
      setw -g pane-base-index 1

      # ===============================
      # Session Management (TMS)
      # ===============================
      bind W display-popup -E "tms --new"
      bind w display-popup -E "tms --sessions"

      # Agent pane picker (any pane publishing the tmux agent protocol)
      bind a display-popup -w 90% -h 80% -E "tmux-agent-panes"

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

      # Forward modifier keys (Shift/Ctrl/Alt+Enter etc) in CSI-u format so
      # pi (and other TUI apps) can distinguish them from plain Enter.
      set -g extended-keys on
      set -g extended-keys-format csi-u

      # Window name rendering fix
      # See: https://github.com/catppuccin/tmux/issues/431
      # Append the agent protocol status to the window pill, alongside the
      # name (#W) and number (#I, rendered separately by catppuccin). The
      # format expands per window against its active pane, so a pane that
      # publishes @agent_status (see docs/tmux-agent-protocol.md) shows it
      # while active; panes without an agent render unchanged.
      #
      # `working` renders as the live spinner frame rather than the word: the
      # pill is a status light, and tmux-agent-spinner keeps @agent_spinner
      # cycling for as long as any pane is working. Other tokens render
      # verbatim, as the protocol requires.
      #
      # The frames are the 8-dot braille rotation, not the 6-dot one agent TUIs
      # spin in their own UI. Ghostty renders braille as a full-cell 2x4 sprite
      # (it draws them for seamless progress bars), so a 6-dot frame lights only
      # the top three of four dot rows and sits a dot row high next to the
      # x-height window name - and bobs a row as the frames rotate. Every 8-dot
      # frame fills all four rows with the same ink box, centered in the cell.
      set -g @agent_spinner "⣾"
      set -g @catppuccin_window_text " #{?#{@agent_status},#{?#{==:#{@agent_status},working},#{@agent_spinner} ,},}#W"
      set -g @catppuccin_window_current_text " #{?#{@agent_status},#{?#{==:#{@agent_status},working},#{@agent_spinner} ,},}#W"

      # The pill's animation clock. tmux only re-expands a status format when
      # something redraws it and has no timer faster than status-interval, so
      # a helper owns the frame; see nix-modules/shared/tmux/tmux-agent-spinner.sh.
      run-shell -b "tmux-agent-spinner"

      # ===============================
      # Plugin Initialization
      # ===============================
      run-shell ${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin/catppuccin.tmux
      run-shell ${pkgs.tmuxPlugins.fzf-tmux-url}/share/tmux-plugins/fzf-tmux-url/fzf-url.tmux
    '';
  };
}
