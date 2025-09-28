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
