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
  # hyprlock authenticates through PAM (/etc/pam.d/hyprlock). A key touch unlocks
  # the screen; the password stays as the fallback in the same stack. The
  # fingerprint block is gone from hyprlock.conf, so nothing else drives the
  # reader any more.
  security.pam.services.hyprlock.u2fAuth = true;

  environment.systemPackages = with pkgs; [
    quickshell
    hyprlock
    hypridle
    hyprpaper
    wl-clipboard
    brightnessctl
    pamixer
    grimblast
    libnotify
    # polkit-gnome installs no bin/; wrap its libexec agent under a stable name so
    # autostart.lua can launch it (the raw /run/current-system/sw/libexec path does
    # not exist on this system, which is why no polkit auth agent was running).
    (writeShellScriptBin "polkit-gnome-auth-agent" ''
      exec ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    '')
    networkmanagerapplet
    nwg-displays
  ];
}
