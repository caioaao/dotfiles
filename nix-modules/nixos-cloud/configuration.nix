{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda"; # adjust for cloud provider

  networking.hostName = "nixos-cloud";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.caio = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINtnL8tBTR9Sx+QSfVMy26nxFiK8l+OZohXreGZyMfny"
    ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  environment.systemPackages = [
    pkgs.ghostty.terminfo
  ];

  security.sudo.enable = true;
  programs.nix-ld.enable = true;

  system.stateVersion = "25.11";
}
