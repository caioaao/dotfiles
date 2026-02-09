{ config, pkgs, ... }:
{
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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

  ### Autostart apps
  environment.etc."xdg/autostart/1password.desktop".source =
    "${pkgs._1password-gui}/share/applications/1password.desktop";

  environment.etc."xdg/autostart/ghostty.desktop".source =
    "${pkgs.ghostty}/share/applications/com.mitchellh.ghostty.desktop";

}
