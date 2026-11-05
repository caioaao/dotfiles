#!/usr/bin/env bash
# Repo-owned Rex worktree terminal helper, derived from rex-worktrunk's
# worktrunk.sh at dcfd281232beaab2606d1eb4f0deffa16e4762ed:
# https://github.com/haxybaxy/rex-worktrunk
# Its pickers were ported from https://github.com/devashish2203/herdr-worktrunk.
# Copyright (c) 2026 Zaid Alsaheb and Devashish Chandra; see LICENSE (MIT).
# Rex session actions live in Lua; this process only picks and invokes wt.
#
# rex-worktree-picker pick [--base BRANCH] [--remotes] [--slugify] [--list]
# rex-worktree-picker remove [--list]
# rex-worktree-picker pr [NUMBER|URL]  (prompt when omitted)

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

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
hold()   { printf '\n\033[31m%s\033[0m press any key to close' "$*"; read -r -n1; echo; }

need() {
    command -v "$1" >/dev/null 2>&1 || { hold "$1 not found on PATH"; exit 1; }
}

in_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || { hold "not a git repository: $PWD"; return 1; }
}

# Worktrunk resolves shortcuts itself, without --create: default (^), previous
# (-), pr:N, mr:N, and PR/MR URLs (all containing a colon).
is_shortcut() {
    case $1 in
        '^'|'-'|*:*) return 0 ;;
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
    command wt list --format=json 2>/dev/null | list_items
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
    if [[ $# -eq 0 ]]; then
        read -r -p 'PR number or GitHub URL (blank cancels): ' target || return 0
        [[ -n $target ]] || return 0
        pr "$target" || { hold 'Could not open PR worktree (see above).'; return 1; }
        return 0
    fi
    if [[ $# -ne 1 ]]; then
        printf 'usage: rex-worktree-picker pr [NUMBER|URL]\n' >&2; return 2
    fi
    if [[ $1 =~ ^[1-9][0-9]*$ ]]; then
        target=pr:$1
    elif [[ $1 =~ ^https://[^/]+/[^/]+/[^/]+/pull/[1-9][0-9]*/?$ ]]; then
        target=$1
    else
        printf 'expected a PR number or GitHub PR URL: %s\n' "$1" >&2; return 2
    fi
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || { printf 'not a git repository: %s\n' "$PWD" >&2; return 1; }
    local tool
    for tool in jq wt gh rex; do
        command -v "$tool" >/dev/null 2>&1 \
            || { printf '%s not found on PATH\n' "$tool" >&2; return 1; }
    done
    switch_worktree "$target"
}

pick() {
    local base="" remotes=false slugify=false list_only=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --base)
                [[ $# -ge 2 ]] || { red 'missing value for --base' >&2; return 2; }
                base=$2; shift 2 ;;
            --remotes) remotes=true; shift ;;
            --slugify) slugify=true; shift ;;
            --list) list_only=true; shift ;;
            *) red "unknown pick option: $1" >&2; return 2 ;;
        esac
    done
    in_repo || return 1
    need jq; need wt

    local refs=(refs/heads)
    $remotes && refs+=(refs/remotes)

    # Refs arrive first; wt then adds checked-out branches. Exclude symbolic
    # remote HEADs (whose short form can be just "origin") and deduplicate.
    candidates() {
        {
            git for-each-ref --format='%(refname) %(refname:short)' "${refs[@]}" 2>/dev/null \
                | awk '$1 !~ /\/HEAD$/ {print $2}'
            wt_items | jq -r 'select(.branch != null) | .branch'
        } | awk '!seen[$0]++ { print; fflush() }'
    }

    if $list_only; then candidates; return $?; fi
    need fzf

    local base_label="default branch"
    if [[ $base == "@" ]]; then
        local current
        current=$(git branch --show-current 2>/dev/null || true)
        [[ -n $current ]] && base_label="current branch ($current)" || base_label="current HEAD"
    elif [[ -n $base ]]; then
        base_label="$base"
    fi

    # Enter selects a match, or creates an unmatched query. Alt-enter returns
    # only the query, so a typed name can override an existing fuzzy match.
    local choice ret name
    choice=$(candidates | fzf --print-query --reverse --info=inline \
        --bind=alt-enter:print-query \
        --prompt='worktree ❯ ' \
        --header="↵ on a match → switch · type a new name + ↵ → create from ${base_label} · alt-↵ → force typed name · esc → cancel")
    ret=$?
    [[ $ret -gt 1 ]] && return 0
    name=${choice##*$'\n'}
    [[ -z $name ]] && return 0

    if $slugify && ! is_shortcut "$name" && ! ref_exists "$name"; then
        local slug
        if ! slug=$(branch_slug "$name"); then
            hold "no valid branch name in: $name"; return 1
        fi
        name=$slug
    fi

    local wtargs=()
    if ! is_shortcut "$name" && ! ref_exists "$name"; then
        wtargs=(--create)
        [[ -n $base ]] && wtargs+=(--base "$base")
    fi
    switch_worktree "$name" "${wtargs[@]}" \
        || { hold 'Could not open worktree (see above).'; return 1; }
}

remove() {
    local list_only=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list) list_only=true; shift ;;
            *) red "unknown remove option: $1" >&2; return 2 ;;
        esac
    done
    in_repo || return 1
    need jq; need wt

    local items cands
    items=$(wt_items) || { hold 'failed to list worktrees'; return 1; }
    # Real, named worktrees only; the current checkout is allowed, never main.
    cands=$(jq -r 'select(.kind == "worktree" and .branch != null and .is_main != true) | .branch' <<<"$items")

    if $list_only; then
        [[ -z $cands ]] || printf '%s\n' "$cands"
        return 0
    fi
    if [[ -z $cands ]]; then
        yellow 'No removable worktrees (only the main worktree exists).'; sleep 2; return 0
    fi
    need fzf

    local name
    name=$(fzf --reverse --info=inline \
        --prompt='remove worktree ❯ ' \
        --header='↵ to remove · dirty checkouts refused; unmerged branches may remain; closes entire Rex session/processes · esc to cancel' <<<"$cands")
    [[ -z $name ]] && return 0

    local wtpath mainpath
    wtpath=$(jq -rs --arg b "$name" '[.[] | select(.kind == "worktree" and .branch == $b) | .path][0] // empty' <<<"$items")
    mainpath=$(jq -rs '[.[] | select(.kind == "worktree" and .is_main == true) | .path][0] // empty' <<<"$items")

    # Capture canonical identities before deletion. No force flags: wt refuses
    # dirty checkouts; a clean unmerged checkout may go while its branch stays.
    # Success closes the entire Rex session, including its running processes.
    wtpath=$(realpath -e -- "$wtpath") || return 1
    mainpath=$(realpath -e -- "$mainpath") || return 1
    if ! command wt remove --foreground -C "$mainpath" "$name"; then
        hold 'wt remove failed (see above).'; return 0
    fi

    rex do worktree_close path="$wtpath" main="$mainpath" >/dev/null \
        || hold "Removed $name, but could not close its Rex session."
}

case ${1:-} in
    normalize) realpath -m -- "${2:?missing path}" ;;
    registry-lock) registry_lock "${2:?missing server scope}" ;;
    registry-unlock) registry_unlock "${2:?missing server scope}" ;;
    registry-exists) directory=$(registry_directory "${2:?missing server scope}") && [[ -e "$directory/sessions.json" ]] ;;
    pick) shift; pick "$@" ;;
    pr) shift; pr "$@" ;;
    remove) shift; remove "$@" ;;
    *) red 'usage: rex-worktree-picker pick [--base BRANCH] [--remotes] [--slugify] [--list] | remove [--list] | pr [NUMBER|URL]' >&2; exit 2 ;;
esac
