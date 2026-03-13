{ pkgs, lib, options, ... }:
let
  ompZenTheme = pkgs.writeText "zen-theme.omp.toml" (lib.readFile ./zen-theme.omp.toml);
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;

    promptInit = ''
      eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config ${ompZenTheme})"
    '';

    interactiveShellInit = ''
      WORDCHARS=
      bindkey -v

      # Vi mode indicator for oh-my-posh
      # https://github.com/JanDeDobbeleer/oh-my-posh/issues/5438
      _omp_redraw-prompt() {
        local precmd
        for precmd in "''${precmd_functions[@]}"; do
          "$precmd"
        done
        zle .reset-prompt
      }

      function _omp_zle-keymap-select() {
        if [ "''${KEYMAP}" = 'vicmd' ]; then
          export POSH_VI_MODE="normal"
        else
          export POSH_VI_MODE="insert"
        fi
        _omp_redraw-prompt
      }

      zle -N zle-keymap-select _omp_zle-keymap-select
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
