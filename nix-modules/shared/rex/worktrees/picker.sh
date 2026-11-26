#!/usr/bin/env bash
# Repo-owned Rex worktree terminal helper, derived from rex-worktrunk's
# worktrunk.sh at dcfd281232beaab2606d1eb4f0deffa16e4762ed:
# https://github.com/haxybaxy/rex-worktrunk
# Its pickers were ported from https://github.com/devashish2203/herdr-worktrunk.
# Copyright (c) 2026 Zaid Alsaheb and Devashish Chandra; see LICENSE (MIT).
# Native Rex actions collect choices; this helper lists targets and runs wt.
#
# rex-worktree-picker branches [--remotes] | removable
# rex-worktree-picker switch NAME [--base BRANCH] [--slugify]
# rex-worktree-picker pr NUMBER|URL | remove NAME

set -uo pipefail

# Keep the registry namespace stable across the local integration cutover.
# Contention fails rather than racing create/rename or silently losing state.
registry_directory() {
    [[ ${1:-} =~ ^[a-zA-Z0-9-]+$ ]] || return 2
    printf '%s/rex/worktrunk/%s' "${XDG_STATE_HOME:-$HOME/.local/state}" "$1"
}

registry_lock() {
    local directory
    directory=$(registry_directory "$1") || return 2
    umask 077
    mkdir -p -- "$directory" || return 1
    if ! mkdir -- "$directory.lock" 2>/dev/null; then
        printf 'session registry is busy: %s.lock; if an action was interrupted, clear this empty lock only after confirming no action is running\n' "$directory" >&2
        return 1
    fi
    printf '%s\n' "$directory"
}

registry_unlock() {
    local directory
    directory=$(registry_directory "$1") || return 2
    rmdir -- "$directory.lock"
}

hold()   { printf '\n\033[31m%s\033[0m press any key to close' "$*"; read -r -n1; echo; }

in_repo() {
    [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) == true ]] \
        || { printf 'not a git repository: %s\n' "$PWD" >&2; return 1; }
}

# Worktrunk resolves shortcuts and PR/MR URLs itself, without --create.
is_shortcut() {
    case $1 in
        '^'|'-'|'@'|*:*) return 0 ;;
        *) return 1 ;;
    esac
}

ref_exists() {
    git show-ref --quiet --verify "refs/heads/$1" \
        || git show-ref --quiet --verify "refs/remotes/$1"
}

branch_slug() {
    local slug
    slug=$(printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -E '
        s#[^a-z0-9._/]+#-#g
        s#-*/+-*#/#g
        s#\.{2,}#.#g
        s#/\.+#/#g
        s#^[-/.]+##
        s#[-/.]+$##
    ')
    [[ -n $slug ]] && git check-ref-format "refs/heads/$slug" || return 1
    printf '%s\n' "$slug"
}

# Accept both wt list schemas, normalizing only the fields used below.
list_items() {
    jq -c '
        def normalize:
            . + {
                kind: (.kind // (if (.worktree | type) == "object" then "worktree" else "branch" end)),
                path: (.path // .worktree.path // null),
                is_main: (.is_main // .worktree.main // false)
            };
        if type == "array" then
            .[] | normalize
        elif type == "object" and ((.items | type) == "array") then
            .items[] | normalize
        else
            error("unsupported worktrunk list JSON schema")
        end
    '
}

wt_items() {
    command wt list --format=json | list_items
}

switch_worktree() {
    local name=$1
    shift
    # Keep hooks and approval prompts in the calling terminal. Rex, not this
    # short-lived shell, changes the viewed session.
    local result wtpath
    if ! result=$(command wt switch "$name" "$@" --no-cd --format=json); then
        printf 'wt switch failed (see above).\n' >&2; return 1
    fi
    wtpath=$(jq -r '.path // empty' <<<"$result" 2>/dev/null)
    if [[ -z $wtpath ]]; then
        wtpath=$(wt_items | jq -rs --arg b "$name" '[.[] | select(.branch == $b and .kind == "worktree") | .path][0] // empty')
    fi
    if [[ -z $wtpath ]]; then
        printf 'worktrunk returned no worktree path for: %s\n' "$name" >&2; return 1
    fi
    if ! rex do worktree_go path="$wtpath" >/dev/null; then
        printf 'Could not open a session for %s.\n' "$wtpath" >&2; return 1
    fi
}

pr() {
    local target
    if [[ $# -ne 1 ]]; then
        printf 'usage: rex-worktree-picker pr NUMBER|URL\n' >&2; return 2
    fi
    if [[ $1 =~ ^[1-9][0-9]*$ ]]; then
        target=pr:$1
    elif [[ $1 =~ ^https://[^/]+/[^/]+/[^/]+/pull/[1-9][0-9]*/?$ ]]; then
        target=$1
    else
        printf 'expected a PR number or GitHub PR URL: %s\n' "$1" >&2; return 2
    fi
    in_repo || return 1
    local tool
    for tool in jq wt gh rex; do
        command -v "$tool" >/dev/null 2>&1 \
            || { printf '%s not found on PATH\n' "$tool" >&2; return 1; }
    done
    switch_worktree "$target"
}

branches() {
    local refs=(refs/heads)
    case ${1:-} in
        --remotes) [[ $# -eq 1 ]] || return 2; refs+=(refs/remotes) ;;
        '') [[ $# -eq 0 ]] || return 2 ;;
        *) return 2 ;;
    esac
    in_repo || return 1
    # Exclude symbolic refs (in particular remote HEAD), then deduplicate.
    {
        git for-each-ref --format='%(refname:short) %(symref)' "${refs[@]}" \
            | awk 'NF == 1 {print $1}' || return
        wt_items | jq -r 'select(.branch != null) | .branch'
    } | awk '!seen[$0]++'
}

switch_target() {
    if [[ $# -eq 0 || -z $1 || ( $1 == -* && $1 != - ) ]]; then
        printf 'expected a branch name or Worktrunk shortcut\n' >&2; return 2
    fi
    local name=$1 base="" slugify=false
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --base)
                [[ $# -ge 2 ]] || { printf 'missing value for --base\n' >&2; return 2; }
                base=$2; shift 2 ;;
            --slugify) slugify=true; shift ;;
            *) printf 'unknown switch option: %s\n' "$1" >&2; return 2 ;;
        esac
    done
    in_repo || return 1

    if $slugify && ! is_shortcut "$name" && ! ref_exists "$name"; then
        local slug
        if ! slug=$(branch_slug "$name"); then
            printf 'no valid branch name in: %s\n' "$name" >&2; return 1
        fi
        name=$slug
    fi

    local wtargs=()
    if ! is_shortcut "$name" && ! ref_exists "$name"; then
        wtargs=(--create)
        [[ -n $base ]] && wtargs+=(--base "$base")
    fi
    switch_worktree "$name" "${wtargs[@]}"
}

# Use the same eligibility rule when listing and when rechecking just before
# removal: real, named, non-main worktrees, including the current checkout.
removable_items() {
    jq -c 'select(.kind == "worktree" and .branch != null and .is_main != true and .path != null)'
}

removable() {
    [[ $# -eq 0 ]] || return 2
    in_repo || return 1
    wt_items | removable_items | jq -r '.branch'
}

remove() {
    [[ $# -eq 1 && -n $1 ]] || { printf 'expected a worktree branch name\n' >&2; return 2; }
    in_repo || return 1
    local name=$1 items wtpath mainpath
    items=$(wt_items) || return 1
    wtpath=$(removable_items <<<"$items" | jq -ers --arg b "$name" '[.[] | select(.branch == $b) | .path][0] // empty') \
        || { printf 'not a removable worktree: %s\n' "$name" >&2; return 1; }
    mainpath=$(jq -ers '[.[] | select(.kind == "worktree" and .is_main == true) | .path][0] // empty' <<<"$items") \
        || { printf 'could not identify the main worktree\n' >&2; return 1; }

    # Capture canonical identities before deletion. No force flags: wt refuses
    # dirty checkouts; a clean unmerged checkout may go while its branch stays.
    # Success closes the entire Rex session, including its running processes.
    wtpath=$(realpath -e -- "$wtpath") || return 1
    mainpath=$(realpath -e -- "$mainpath") || return 1
    if ! command wt remove --foreground -C "$mainpath" -- "$wtpath"; then
        printf 'wt remove failed (see above).\n' >&2; return 1
    fi

    rex do worktree_close path="$wtpath" main="$mainpath" >/dev/null \
        || { printf 'Removed %s, but could not close its Rex session.\n' "$name" >&2; return 1; }
}

case ${1:-} in
    normalize) realpath -m -- "${2:?missing path}" ;;
    registry-lock) registry_lock "${2:?missing server scope}" ;;
    registry-unlock) registry_unlock "${2:?missing server scope}" ;;
    registry-exists) directory=$(registry_directory "${2:?missing server scope}") && [[ -e "$directory/sessions.json" ]] ;;
    branches) shift; branches "$@" ;;
    removable) shift; removable "$@" ;;
    switch) shift; switch_target "$@" || { hold 'Could not open worktree (see above).'; exit 1; } ;;
    pr) shift; pr "$@" || { hold 'Could not open PR worktree (see above).'; exit 1; } ;;
    remove) shift; remove "$@" || { hold 'Could not complete worktree removal (see above).'; exit 1; } ;;
    *) printf 'usage: rex-worktree-picker branches [--remotes] | removable | switch NAME [--base BRANCH] [--slugify] | pr NUMBER_OR_URL | remove NAME\n' >&2; exit 2 ;;
esac
