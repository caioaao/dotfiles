# omp (oh-my-pi) packages linked under /run/current-system/sw/share/omp; the
# stowed config.yml lists each directory under `extensions:`.
#
# wayfinder-loop: TypeScript extension adding `/wayfind <map>`, which runs the
# wayfinder skill over a map one ticket per fresh session (see its header).
# omp loads the .ts source directly with Bun, so the package is the file.
#
# mattpocock-skills: skills vendored from github.com/mattpocock/skills,
# shipped as an extension package whose sibling `skills/` omp discovers
# (omp-plugins provider). pi reads the same directory as a package
# (conventional `skills/`), listed in the stowed ~/.pi/agent/settings.json.
# Update by copying upstream skills/<category>/<name>/ over skills/<name>/.
# Local patches to re-apply after an update: grilling/SKILL.md (max 4
# questions per round; ask via the harness's structured question tool).
#
# caioaao-extra: MCP servers, declared per box. Box modules add entries to
# programs.omp.mcpServers (attrsets merge across modules, so a downstream
# private flake can append its own). The result is an omp extension package
# at /run/current-system/sw/share/omp/caioaao-extra containing only mcp.json;
# the stowed config.yml lists that directory under `extensions:`.
#
# Why an extension package rather than the user .mcp.json: omp only writes
# back to MCP files it owns (agent-dir mcp.json/.mcp.json). Servers from an
# extension package are read-only to it, so /mcp disable and the extensions
# dashboard toggle record the change in the local mcp.json's
# `disabledServers` instead - and the file lives in the read-only store
# anyway. A same-named server in mcp.json still wins (native > omp-plugins).
#
# Entries use omp's mcp.json server shape (omp docs: mcp-config.md).
# Reference binaries by store path ("${pkgs.foo}/bin/foo") so the dependency
# ships with the config. omp expands ${VAR} at load time; escape it in Nix
# strings as "\${VAR}" or ''${VAR}.
#
# config.yml: per-box settings overlay. Box modules set programs.omp.settings
# (e.g. modelRoles.default); the result lands at
# /run/current-system/sw/share/omp/config.yml and PI_CONFIG_FILES points omp
# at it. Overlays sit above the stowed global config.yml (deep merge: objects
# merge per key, scalars/arrays replace), so any key set here is nix-owned:
# /model or /settings still persist to config.yml, but the overlay wins on the
# next start. The file always exists while this module is imported (an empty
# mapping when nothing is set) - omp hard-fails on a missing overlay.
# Verify the effective value with `omp config get modelRoles`.
{ config, lib, pkgs, ... }:
let
  json = pkgs.formats.json { };
in
{
  options.programs.omp = {
    mcpServers = lib.mkOption {
      type = lib.types.attrsOf json.type;
      default = { };
      description = "MCP servers exposed to omp through the caioaao-extra extension package.";
    };

    settings = lib.mkOption {
      type = json.type;
      default = { };
      description = "Per-box omp settings, loaded as a PI_CONFIG_FILES overlay above the stowed config.yml.";
    };
  };

  config = {
    environment.pathsToLink = [ "/share/omp" ];
    environment.variables.PI_CONFIG_FILES = "/run/current-system/sw/share/omp/config.yml";
    environment.systemPackages = [
      # JSON is valid YAML; omp parses overlays as config.yml.
      (pkgs.writeTextDir "share/omp/config.yml"
        (builtins.toJSON config.programs.omp.settings))
      (pkgs.writeTextDir "share/omp/caioaao-extra/mcp.json"
        (builtins.toJSON { mcpServers = config.programs.omp.mcpServers; }))
      (pkgs.writeTextDir "share/omp/wayfinder-loop/index.ts"
        (builtins.readFile ./wayfinder-loop/index.ts))
      (pkgs.runCommand "omp-mattpocock-skills" { } ''
        mkdir -p $out/share/omp
        cp -r ${./mattpocock-skills} $out/share/omp/mattpocock-skills
      '')
    ];

    # Fallback for boxes that don't pick their own
    programs.omp.settings.modelRoles.default = lib.mkDefault "anthropic/claude-opus-5-5";
  };
}
