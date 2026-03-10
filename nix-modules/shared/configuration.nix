{ pkgs, ... }: 
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

  rtk = pkgs.stdenv.mkDerivation rec {
    pname = "rtk";
    version = "0.27.0";
    src = let
      sources = {
        x86_64-linux = pkgs.fetchurl {
          url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-3Y425o0+1z2/fvJPlRdJibU7bUL8OvBcgwt6stJgb2s=";
        };
        aarch64-darwin = pkgs.fetchurl {
          url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-aarch64-apple-darwin.tar.gz";
          hash = "sha256-XOvNnVd/bYSvHZWWEMGPPAtGuAlXwmkmFLhwj6ykLUw=";
        };
      };
    in sources.${pkgs.stdenv.hostPlatform.system}
      or (throw "rtk: unsupported system ${pkgs.stdenv.hostPlatform.system}");
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/bin
      cp rtk $out/bin/rtk
      chmod +x $out/bin/rtk
    '';
  };
in {
  imports = [
    ./tmux/default.nix
    ./zsh/default.nix
  ];

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
    github-cli
    gum
    just
    jq
    mise
    neovim
    nodejs
    nixd
    obsidian
    oh-my-posh
    ripgrep
    rtk
    stdenv
    stow
    unzip
    wget
  ];
}
