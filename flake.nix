{
  description = "One flake for NixOS + macOS (nix-darwin) with shared config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # nix-darwin for macOS system configuration
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-darwin, ... }:
    let
      # Pick the CPU/OS for each machine
      linuxSystem = "x86_64-linux"; 
      macSystem   = "aarch64-darwin"; 

      # Shared settings used by BOTH machines
      sharedModule = { pkgs, ... }: {
        nixpkgs.config.allowUnfree = true;

        programs.zsh.enable = true;

        programs.tmux = {
          enable = true;
          escapeTime = 10;
          shortcut = "q";
          keyMode = "vi";
          aggressiveResize = true;
          historyLimit = 5000;

          plugins = with pkgs.tmuxPlugins; [
            catppuccin
            fzf-tmux-url
            resurrect
          ]; 

          extraConfigBeforePlugins = ''
            set -g @catppuccin_window_status_style "rounded"
            set -g @catppuccin_flavor "latte"

            # Make sure the window names are properly rendered (https://github.com/catppuccin/tmux/issues/431)
            set -g @catppuccin_window_text "#W"
            set -g @catppuccin_window_current_text " #W"
          '';

          extraConfig = ''
            # reload config
            bind r source-file /etc/tmux.conf

            # Enable clipboard passthrough
            set -g set-clipboard on
            set -g allow-passthrough on

            # Enable mouse support
            set -g mouse on


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
          '';
        };

        environment.systemPackages = with pkgs; [
          pkgs.git
          pkgs.wget
          pkgs.ripgrep
          pkgs.fd
          pkgs.fzf
          pkgs.neovim
          pkgs.direnv
          pkgs.stow
          pkgs.just
          pkgs.zoxide
          pkgs.oh-my-zsh
          pkgs._1password-cli
          pkgs.stdenv
          pkgs.unzip
        ];
      };
    in {
      # ---------- NixOS ----------
      nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        modules = [
          ./hosts/nixos/configuration.nix
          sharedModule
        ];
      };

      # ---------- darwin ----------
      darwinConfigurations."darwin" = nix-darwin.lib.darwinSystem {
        system = macSystem;
        modules = [
          ./hosts/darwin/configuration.nix
          sharedModule
        ];
      };
    };
}

