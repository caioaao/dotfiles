{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  fd,
  ripgrep,
}:

let
  version = "0.71.1";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-OPlYLfgVq9FmbINMixzFkmxlWTmmGBqLwCHe9g1rbEk=";
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
  npmDepsHash = "sha256-X/hxlEdk1/6ku3u9qOjOugGiku9IqIrS9E5vf2DFObY=";
  makeCacheWritable = true;
  dontNpmBuild = true;
  postInstall = ''
    wrapProgram $out/bin/pi \
      --prefix PATH : ${lib.makeBinPath [ fd ripgrep ]} \
      --set PI_SKIP_VERSION_CHECK 1
  '';
}
