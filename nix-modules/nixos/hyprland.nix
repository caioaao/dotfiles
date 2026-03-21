{ pkgs, ... }:
{
  programs.hyprland.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.hyprland = {
      default = [ "hyprland" "gtk" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    };
  };

  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;

  # Chromium needs a Secret Service provider to encrypt cookies/passwords.
  # Without this it falls back to plaintext storage.
  services.gnome.gnome-keyring.enable = true;

  security.polkit.enable = true;
  security.pam.services.hyprlock.fprintAuth = true;

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
    nwg-displays
  ];
}
