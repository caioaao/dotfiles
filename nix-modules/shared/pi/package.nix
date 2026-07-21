{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  fd,
  ripgrep,
}:

# pi - terminal-based coding agent.
#
# Upstream moved from `badlogic/pi-mono` (npm: `@mariozechner/pi-coding-agent`)
# to `earendil-works/pi` (npm: `@earendil-works/pi-coding-agent`) in April 2026.
# See: https://mariozechner.at/posts/2026-04-08-ive-sold-out/ for the rationale.
# The CLI binary is still `pi`; only the scope/owner changed.

let
  version = "0.81.1";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-QgETwCghYOYYFlb9Fs8YdC92v5BA7j37nLZ+PmrVZBw=";
  };
  srcWithLock = runCommand "pi-${version}-src" {} ''
    mkdir -p $out
    tar -xzf ${tarball} -C $out --strip-components=1
    rm -f $out/npm-shrinkwrap.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "pi";
  inherit version;
  src = srcWithLock;
  npmDepsHash = "sha256-6UJTqK+CfTrmm2sa/H7Yl+MsmpDtX7BmarerQ4FsfrM=";
  makeCacheWritable = true;
  dontNpmBuild = true;
  npmFlags = [ "--legacy-peer-deps" ];
  postInstall = ''
    wrapProgram $out/bin/pi \
      --prefix PATH : ${lib.makeBinPath [ fd ripgrep ]} \
      --set PI_SKIP_VERSION_CHECK 1
  '';

  meta = {
    description = "Terminal-based coding agent (pi)";
    homepage    = "https://pi.dev/";
    license     = lib.licenses.mit;
    platforms   = lib.platforms.unix;
    mainProgram = "pi";
  };
}
