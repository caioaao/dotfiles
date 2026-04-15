{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  fd,
  ripgrep,
}:

let
  version = "0.67.3";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-szDvpJxudzKmq85xZhrnSBHOGekqwijLdE6WIgCvMS8=";
  };
  srcWithLock = runCommand "pi-coding-agent-${version}-src" {} ''
    mkdir -p $out
    tar -xzf ${tarball} -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "pi-coding-agent";
  inherit version;
  src = srcWithLock;
  npmDepsHash = "sha256-aAZreVacnUtKz9oUeaa45pcb6V/H5WQBrx0RNuk0B4k=";
  makeCacheWritable = true;
  dontNpmBuild = true;
  postInstall = ''
    wrapProgram $out/bin/pi \
      --prefix PATH : ${lib.makeBinPath [ fd ripgrep ]} \
      --set PI_SKIP_VERSION_CHECK 1
  '';
}
