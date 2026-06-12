# tsserve-file: serve a single file over the tailnet (miniserve on
# localhost + `tailscale serve` proxying it). Foreground only by design -
# backgrounding (tmux, &, etc.) is the caller's responsibility, so no --bg.
# `tailscale` is taken from the ambient PATH on purpose: darwin gets it from
# the Tailscale app, NixOS from services.tailscale.
{ pkgs, ... }: {
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "tsserve-file";
      runtimeInputs = [ pkgs.miniserve ];
      text = builtins.readFile ./tsserve-file.sh;
    })
  ];
}
