{ config, pkgs, ... }:
{
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Turn on the dconf module (lets us set GNOME/GSettings system-wide)
  programs.dconf = {
    enable = true;

    profiles.user.databases = [
      # --- System-wide GNOME settings ---
      {
        lockAll = true;
        settings = {
          "org/gnome/desktop/wm/keybindings" = {
            # Move window to half screen (tiling)
            move-to-side-w = [ "<Super>Left" ];
            move-to-side-e = [ "<Super>Right" ];

            # Move window across monitors
            move-to-monitor-left = [ "<Super><Alt>Left" ];
            move-to-monitor-right = [ "<Super><Alt>Right" ];

            # Toggle maximize
            toggle-maximized = [ "<Super>Up" ];

            # Close current window
            close = [ "<Super>Q" ];
          };
        };
      }
    ];
  };
}
