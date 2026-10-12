# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./hyprland.nix
      ./helium.nix
      ./anytype.nix
      ./paper.nix
      ../nixos-shared/tailscale.nix
      ../nixos-shared/resolved.nix
    ];

  # Use Grub while I test it alongside Fedora
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.useOSProber = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    nerd-fonts.symbols-only
    nerd-fonts.jetbrains-mono
  ];

  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/Sao_Paulo";

  # Internationalisation: UI in English, compose/ctype in PT-BR
  # so that dead_acute + c = ç (not ć)
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "pt_BR.UTF-8/UTF-8"
  ];

  # Configure keymap in X11
  services.xserver.xkb.layout = "us";

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
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
    openFirewall = false;
    settings.PasswordAuthentication = false;
  };

  # Only allow SSH through Tailscale
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [];
    interfaces."tailscale0" = {
      allowedTCPPorts = [ 22 ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  programs.vim.enable = true;
  programs.firefox.enable = true;
  programs.chromium.enable = true;
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "caio" ];
  }; 

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-qt;
  };

  # omp settings overlay for this box; see nix-modules/shared/omp.
  programs.omp.settings.modelRoles.default = "deepseek/deepseek-flash";

  security.sudo.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim
    ghostty
    keyd
    yubioath-flutter
    python3
    # pamu2fcfg, to register a key. The module itself is wired up through
    # security.pam.u2f; this is only here because `pamu2fcfg` is installed
    # alongside pkgs.pam_u2f when security.pam.u2f.enable is on, and we opt
    # services in per-service instead.
    pam_u2f
  ];

  # Set up keyboard options by device
  hardware.uinput.enable = true;        # needed by keyd
  services.keyd = {
    enable = true;

    # Declarative keyd config (no manual file editing)
    keyboards = {
      default = {
        # [ids] section - match all keyboards, but exclude the Moonlander by id
        ids = [ "*" "-3297:1969" ];

        # [main] section - swap caps and left control
        settings.main = {
          capslock    = "layer(control)";
          leftcontrol = "capslock";
        };

        # If you ever need raw blocks beyond settings:
        # extraConfig = ''' … ''';
      };
    };
  };

  # List services that you want to enable:

  ### YubiKey (U2F) authentication
  # The Synaptics 06cb:00fc reader is retired. It is match-in-sensor: libfprint
  # never sees an image and the firmware owns matching, so nothing on this side
  # could ever make it recognise a finger reliably. The YubiKey is the touch
  # factor instead, on the same entry points the fingerprint used to cover.
  #
  # `control` defaults to "sufficient": a successful touch authenticates, and
  # every other outcome (no key plugged in, no mapping for the user, wrong
  # device) falls through to the password module below it in the same stack, so
  # this cannot lock you out.
  security.pam.u2f = {
    # `enable` only sets the default of the per-service `u2fAuth` below, and is
    # what pulls `pamu2fcfg` into systemPackages. Left off so pam_u2f stays out
    # of stacks we never asked for (sshd, su, passwd, useradd, chfn, ...).
    enable = false;
    settings.cue = true; # "Please touch the device" via the PAM conversation
  };

  security.pam.services.sudo.u2fAuth     = true;  # sudo
  security.pam.services.polkit-1.u2fAuth = true;  # GUI auth dialogs

  # (Optional) firmware updates via LVFS
  services.fwupd.enable = true;

  # PCSC-lite daemon, to access smart cards (Yubikey)
  services.pcscd.enable = true;

  programs.nix-ld.enable = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}

