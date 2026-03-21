{ pkgs, ... }:
{
  programs.hyprland.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;

  security.polkit.enable = true;

  environment.systemPackages = with pkgs; [
    waybar
    fuzzel
    mako
    hyprlock
    hypridle
    hyprpaper
    wl-clipboard
    brightnessctl
    pamixer
    grimblast
    libnotify
    polkit_gnome
    networkmanagerapplet
  ];
}
