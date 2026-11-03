{ pkgs, lib, options, ... }:
let
  ompZenTheme = pkgs.writeText "zen-theme.omp.toml" (lib.readFile ./zen-theme.omp.toml);
in
{
  # https://raw.githubusercontent.com/catppuccin/fzf/refs/heads/main/themes/catppuccin-fzf-mocha.sh
  environment.variables.FZF_DEFAULT_OPTS = lib.concatStringsSep " " [
    "--color=bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8"
    "--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC"
    "--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8"
    "--color=selected-bg:#45475A"
    "--color=border:#6C7086,label:#CDD6F4"
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    promptInit = ''
      eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config ${ompZenTheme})"
    '';

    interactiveShellInit = ''
      WORDCHARS=
      # Vi mode indicator handled natively by oh-my-posh (>= 29.18) via the
      # `vimode` segment in the theme, which registers zle-keymap-select.
      bindkey -v

      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh

      # Jump to a directory without relying on terminal Meta-key handling.
      j() {
        local dir
        dir=$(FZF_DEFAULT_COMMAND="''${FZF_ALT_C_COMMAND:-}" \
          ${pkgs.fzf}/bin/fzf --reverse --walker=dir,follow,hidden --scheme=path +m) || return
        [[ -n "$dir" ]] && builtin cd -- "$dir"
      }
    '';
  }
  // lib.optionalAttrs (options.programs.zsh ? enableSyntaxHighlighting) {
    # Darwin syntax highlighting option
    enableSyntaxHighlighting = true;
  }
  // lib.optionalAttrs (options.programs.zsh ? syntaxHighlighting) {
    # NixOS syntax highlighting option
    syntaxHighlighting.enable = true;
  }
  // lib.optionalAttrs (options.programs.zsh ? autosuggestions) {
    # NixOS autosuggestions option
    autosuggestions.enable = true;
  };
}
