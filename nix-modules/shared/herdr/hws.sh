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
# mangling.
#
# Naming has two authorities and they drift apart. `workspace list`
# returns `label`, frozen when the worktree was created from its
# directory name. The sidebar renders the live git branch. Rename or
# switch a branch and the picker stops matching what you see in the
# sidebar. So hws joins against `worktree list` and displays repo/branch,
# falling back to `label` for workspaces with no worktree. A label that
# matches neither is kept in brackets, since a manual `rename_workspace`
# is intent, not drift.

set -euo pipefail

# HERDR_BIN_PATH is injected into managed panes and is the documented
# portable handle. Fall back to PATH when invoked outside herdr.
herdr="${HERDR_BIN_PATH:-herdr}"

workspaces="$("$herdr" workspace list)"

# `worktree list` is repo-scoped, so one call per distinct repo_key is
# enough to cover every worktree workspace of that repo. Failures here
# are non-fatal: a pruned or unreachable repo just degrades that row to
# its label.
repo_probes="$(
	printf '%s' "$workspaces" | jq -r '
		.result.workspaces
		| map(select(.worktree))
		| group_by(.worktree.repo_key)
		| map(.[0].workspace_id)
		| .[]
	'
)"

branches="$(
	for ws in $repo_probes; do
		"$herdr" worktree list --workspace "$ws" || true
	done | jq -s '
		[ .[]
		| (.result.worktrees? // [])
		| .[]
		| select(.open_workspace_id)
		| { key: .open_workspace_id
		  , value: { repo: .label, branch: .branch }
		  }
		]
		| from_entries
	'
)"

# Focused workspace sorts last so it is never the default pick, while
# staying selectable. Avoids an empty list when only one workspace exists.
rows="$(
	printf '%s' "$workspaces" | jq -r --argjson branches "$branches" '
		.result.workspaces
		| sort_by(.focused)
		| map(
			($branches[.workspace_id]) as $wt
			| . + { text:
				(if .focused then "* " else "  " end)
				+ (if $wt == null then .label
				   else $wt.repo + "/" + $wt.branch
					+ (if .label != $wt.branch and .label != $wt.repo
					   then " [" + .label + "]"
					   else "" end)
				   end)
			  }
		  )
		| (map(.text | length) | max) as $width
		| .[]
		| [ .workspace_id
		  , .text + ((" " * ($width - (.text | length))) // "")
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
