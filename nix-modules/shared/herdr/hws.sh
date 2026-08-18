#!/usr/bin/env bash
#
# hws - fuzzy workspace switcher for herdr.
#
# Bound to prefix+w as a `type = "popup"` custom command; see
# stow-modules/herdr/.config/herdr/config.toml.
#
# Three stages, three concerns: herdr owns workspace identity and
# persistence, fzf owns matching, this script only adapts between them.
# It deliberately holds no state of its own - no MRU file, no name
# mangling. The socket API exposes neither a cwd nor a last-attached
# timestamp, so `label` is the only handle worth matching against.

set -euo pipefail

# HERDR_BIN_PATH is injected into managed panes and is the documented
# portable handle. Fall back to PATH when invoked outside herdr.
herdr="${HERDR_BIN_PATH:-herdr}"

# Focused workspace sorts last so it is never the default pick, while
# staying selectable. Avoids an empty list when only one workspace exists.
rows="$(
	"$herdr" workspace list | jq -r '
		.result.workspaces
		| sort_by(.focused)
		| .[]
		| [ .workspace_id
		  , (if .focused then "* " else "  " end) + .label
		  , .agent_status
		  ]
		| @tsv
	'
)"

[ -n "$rows" ] || exit 0

# fzf exits 130 on Esc and 1 on no match; both mean "user changed their
# mind", not failure.
selected="$(
	printf '%s\n' "$rows" | fzf \
		--delimiter='\t' \
		--with-nth='2..' \
		--no-sort \
		--no-multi \
		--height='100%' \
		--prompt='workspace> '
)" || exit 0

exec "$herdr" workspace focus "${selected%%$'\t'*}"
