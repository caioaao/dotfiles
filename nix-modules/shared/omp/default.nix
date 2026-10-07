# omp (oh-my-pi) packages linked under /run/current-system/sw/share/omp; the
# stowed config.yml lists each directory under `extensions:`.
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
{ config, lib, pkgs, ... }:
let
  json = pkgs.formats.json { };
in
{
  options.programs.omp.mcpServers = lib.mkOption {
    type = lib.types.attrsOf json.type;
    default = { };
    description = "MCP servers exposed to omp through the caioaao-extra extension package.";
  };

  config = {
    environment.pathsToLink = [ "/share/omp" ];
    environment.systemPackages = [
      (pkgs.writeTextDir "share/omp/caioaao-extra/mcp.json"
        (builtins.toJSON { mcpServers = config.programs.omp.mcpServers; }))
    ];
  };
}
