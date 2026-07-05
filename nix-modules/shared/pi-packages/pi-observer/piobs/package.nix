{
  lib,
  buildGoModule,
}:

# piobs - observer CLI/TUI for pi sessions (read side of ../CONTRACT.md).
# A normal system binary, not a pi package: it must not be linked into
# share/pi/packages.
buildGoModule {
  pname = "piobs";
  version = "0.2.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./go.sum
      ./main.go
      ./distill_cmd.go
      ./tui_cmd.go
      ./internal
    ];
  };

  vendorHash = "sha256-FkWZ0BXXhxUGA2OCvn27I2EtdVQHuuSuYPrc2A8ELUI=";

  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
  ];

  # tmux and ps are invoked from PATH at runtime on purpose: they are
  # user-environment concerns and ps ships with every system.

  meta = {
    description = "Big-picture TUI feed of active pi sessions";
    mainProgram = "piobs";
  };
}
