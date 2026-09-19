# Tmux Behavior

`tms -d -- "$worktree_path"` creates or reuses a detached session and prints its
name. An explicit path avoids the interactive picker. Without `-d`, it attaches
or switches the current client.

- Projects are expected under `${PROJECTS_DIR:-$HOME/reps}`. The normal path
  argument is canonicalized, but the projects-directory prefix is not. Outside
  paths, symlinked roots, or trailing slashes can produce the wrong working path.
- `--new` and `--sessions` handle their operands differently, bypassing normal
  path normalization; they are primarily picker modes.
- Session names come from the project-relative path with periods replaced by
  double underscores. Different paths can therefore collide. Pane start
  directories help distinguish an intended session from an unrelated one.
- A new session gets an `nvim` window and a shell window. An existing session is
  reused without checking or repairing its contents.
- Tmux's `=` target prefix selects an exact session name, for example in
  `tmux has-session -t "=$session_name"`.
