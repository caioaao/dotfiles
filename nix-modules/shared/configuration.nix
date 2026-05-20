{ pkgs, lib, ... }:
let
  # git-spice package has a test error
  git-spice = pkgs.buildGoModule rec {
    pname = "git-spice";
    version = "0.16.1";
    src = pkgs.fetchFromGitHub {
      owner = "abhinav";
      repo  = "git-spice";
      rev   = "v${version}";
      hash  = "sha256-SILcEXyUo73c8gPDDESCkm/eQIh8elM850qwJqTyO6E=";
    };
    vendorHash = "sha256-T6zSwQdDWYQqe8trIlhpU8dUQXtz8OGmnW5L5AVjGn8=";
    subPackages = [ "." ];
  };

  # @plannotator/pi-extension: registers plannotator as a pi extension/skill.
  # Built from the npm tarball with a vendored lockfile so we don't need any
  # global npm install. Exposed at /etc/pi-packages/plannotator-pi-extension
  # below and referenced from stow-modules/pi/.pi/agent/settings.json.
  plannotator-pi-extension = pkgs.callPackage ./plannotator-pi-extension/package.nix {};

  # plannotator: prebuilt single-file binary published to GitHub releases.
  # Upstream's only install path is `curl … | bash` which writes to ~/.local/bin;
  # we package it as a regular Nix derivation so it lives in /run/current-system
  # and gets rebuilt/pinned via the flake.
  plannotator = let
    version = "0.19.14";
    sources = {
      "aarch64-darwin" = {
        asset = "plannotator-darwin-arm64";
        hash  = "sha256-9yAtGIQylW/0K9jMl8Ak076fgDaYBlWB5Yl+czOpd+s=";
      };
      "x86_64-linux" = {
        asset = "plannotator-linux-x64";
        hash  = "sha256-5tVu6ArVOIZNL+eqSzJcMje0OiLdk/G1582V1glhv4w=";
      };
    };
    src = sources.${pkgs.stdenv.hostPlatform.system} or
      (throw "plannotator: unsupported system ${pkgs.stdenv.hostPlatform.system}");
    isLinux = pkgs.stdenv.hostPlatform.isLinux;
  in pkgs.stdenv.mkDerivation {
    pname = "plannotator";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://github.com/backnotprop/plannotator/releases/download/v${version}/${src.asset}";
      hash = src.hash;
    };
    dontUnpack = true;
    # Bun-compiled standalone binary on Linux still needs the glibc dynamic
    # linker patched in; autoPatchelfHook handles that. No-op on Darwin.
    nativeBuildInputs = lib.optional isLinux pkgs.autoPatchelfHook;
    buildInputs = lib.optionals isLinux (with pkgs; [ stdenv.cc.cc.lib ]);
    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/plannotator
      runHook postInstall
    '';
    meta = {
      description = "Interactive plan review for coding agents (annotate plans visually, send feedback)";
      homepage    = "https://github.com/backnotprop/plannotator";
      license     = with lib.licenses; [ mit asl20 ];
      platforms   = lib.attrNames sources;
      mainProgram = "plannotator";
    };
  };
in {
  imports = [
    ./tmux/default.nix
    ./zsh/default.nix
  ];

  # Stable path for the pi extension. Pi resolves local-path packages by
  # absolute path, so we anchor it under /etc rather than a /nix/store path
  # that changes on every rebuild.
  environment.etc."pi-packages/plannotator-pi-extension".source =
    "${plannotator-pi-extension}/pi-extension";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  programs.direnv.enable = true;

  environment.systemPackages = with pkgs; [
    _1password-cli
    bc
    claude-code
    direnv
    fd
    fzf
    gemini-cli
    git
    git-revise
    git-spice
    git-lfs
    pi
    plannotator
    github-cli
    gum
    just
    jq
    mise
    neovim
    nodejs
    tree-sitter
    nixd
    oh-my-posh
    ripgrep
    gcc
    stow
    unzip
    wget
  ];
}
