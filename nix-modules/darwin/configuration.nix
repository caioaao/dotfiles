{ pkgs, ... }:

{
  # Set your user and shell
  users.users.caio = {
    name = "caio";
    home = "/Users/caio";
    shell = pkgs.zsh;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableSyntaxHighlighting = true;
    promptInit = ''
      eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config ${pkgs.oh-my-posh}/share/oh-my-posh/themes/catppuccin_latte.omp.json)"
    '';
  };

  system.stateVersion = 6;  # 25.05"
}
