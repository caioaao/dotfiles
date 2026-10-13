# Raycast Store extensions, declared per box as "<owner-or-author>/<name>"
# (the path of the extension's store URL, raycast.com/<id>). Lists merge across
# modules, so a downstream private flake can append its own.
#
# Raycast has no CLI or config file for installing Store extensions: the
# installed set lives in its own (encrypted) database. So this list is the
# desired state and `raycast-sync` converges towards it: for every entry not
# yet installed it opens raycast://extensions/<id>, the Store page the
# website's "Install" button opens, where one ⏎ installs it. Installed
# entries are skipped, so re-running is a no-op once everything is in.
#
# Installed extensions are detected from their manifests in
# ~/.config/raycast/extensions/*/package.json: the store id is
# `owner // author` + "/" + `name` (org extensions publish under the owner).
#
# One-way: removing an entry doesn't uninstall the extension (do that in
# Raycast), and extension preferences stay in Raycast.
{ config, lib, pkgs, ... }:
let
  raycast-sync = pkgs.writeShellApplication {
    name = "raycast-sync";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      shopt -s nullglob
      manifests=("$HOME"/.config/raycast/extensions/*/package.json)
      installed=""
      if [ ''${#manifests[@]} -gt 0 ]; then
        installed=$(jq -r '"\(.owner // .author)/\(.name)"' "''${manifests[@]}")
      fi
      wanted=(${lib.escapeShellArgs config.programs.raycast.extensions})
      for id in "''${wanted[@]}"; do
        if grep -qxF "$id" <<<"$installed"; then
          continue
        fi
        echo "opening Store page for $id - press ⏎ in Raycast to install"
        open "raycast://extensions/$id"
      done
    '';
  };
in
{
  options.programs.raycast.extensions = lib.mkOption {
    type = lib.types.listOf (lib.types.strMatching "[^/]+/[^/]+");
    default = [ ];
    description = "Raycast Store extensions (\"<owner-or-author>/<name>\") that `raycast-sync` installs.";
  };

  config.environment.systemPackages = [ raycast-sync ];
}
