# Squid forward proxy with domain allowlist for sandbox VMs.
#
# Binds to the bridge interface (10.100.0.1:3128) and allows only
# explicitly allowlisted domains.  HTTPS is filtered via the CONNECT
# method's target hostname — no ssl_bump / MITM required.
#
# VM-side proxy env vars are already configured in modules/vm/network.nix.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.claude-sandbox;

  defaultDomains = [
    # Anthropic API + auth
    ".anthropic.com"
    ".claude.ai"
    ".auth0.com"

    # Nix
    ".cache.nixos.org"
    ".nixos.org"

    # Package registries
    ".npmjs.org"
    ".yarnpkg.com"
    ".pypi.org"
    ".pythonhosted.org"
    ".crates.io"
    ".static.crates.io"

    # Git
    ".github.com"
    ".githubusercontent.com"
    ".gitlab.com"
  ];

  allDomains = defaultDomains ++ cfg.allowedDomains;

  allowlistFile = pkgs.writeText "sandbox-allowlist" (
    lib.concatStringsSep "\n" allDomains
  );

  squidConfig = ''
    # Bind only to the sandbox bridge interface
    http_port ${cfg.bridge.hostAddress}:3128

    # Domain allowlist (loaded from file)
    acl sandbox_allowed dstdomain "${allowlistFile}"

    # Allow HTTP and CONNECT to allowlisted domains only
    http_access allow sandbox_allowed

    # Deny everything else
    http_access deny all

    # Access logging with timestamp, domain, and status
    access_log stdio:${cfg.accessLog} squid

    # No caching — this is a filtering proxy
    cache deny all

    # Don't leak proxy info
    forwarded_for off
    via off

    # Hostname for error pages
    visible_hostname claude-sandbox-proxy
  '';
in
{
  options.services.claude-sandbox = {
    allowedDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional domains to allow through the sandbox proxy (merged with built-in defaults).";
    };

    accessLog = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/claude-sandbox/access.log";
      description = "Path to the Squid proxy access log file.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.squid = {
      enable = true;
      configText = squidConfig;
    };

    # Create the access log directory
    systemd.tmpfiles.rules = [
      "d /var/log/claude-sandbox 0750 squid squid -"
    ];
  };
}
