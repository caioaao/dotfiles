# Rex personal server for this laptop, reached from the Rex for Mac client
# through an SSH-forwarded Unix socket. Linux is server-only; the client is
# the macOS app.
#
# A personal server, not the shared or login server: it runs as caio, so
# sessions use this home directory, dotfiles and worktrees. It also uses the
# same XDG_RUNTIME_DIR socket as every local `rex` command, so local and
# forwarded clients reach the same server and sessions.
{ config, ... }:

let
  rex = config.services.rex.package;
in {
  environment.systemPackages = [ rex ];

  # Keep the user manager, and therefore the server, running while caio is
  # logged out. Without lingering, the SSH forward fails after logout.
  users.users.caio.linger = true;

  # The unit Rex's home-manager module installs for a personal server, written
  # directly because this host does not use home-manager. No --listen or
  # --state-dir: the user manager supplies XDG_RUNTIME_DIR, so `rex server
  # status` and the forwarded socket find this same server.
  systemd.user.services.rex = {
    description = "Rex Server";
    documentation = [ "https://superlogical.com" ];
    after = [ "network-online.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "notify";
      NotifyAccess = "main";
      ExecStart = "${rex}/bin/rex server run";
      Environment = [
        "TERMINFO_DIRS=${rex}/share/terminfo:"
        "GODEBUG="
      ];
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # ssh from a Rex terminal must not send TERM=xterm-rex to hosts that lack
  # the entry. Same guard the nixpkgs module would add.
  programs.ssh.extraConfig = ''
    Include ${rex}/share/rex/ssh_config.d/50-rex.conf
  '';
}
