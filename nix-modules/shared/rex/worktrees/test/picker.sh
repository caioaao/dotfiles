#!/usr/bin/env bash
# Public helper integration tests: real Git repositories and wt operations.
# Rex callbacks are recorded separately from the app's native prompts.
# Run: PICKER=/path/to/rex-worktree-picker bash test/picker.sh

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script=${PICKER:-$root/picker.sh}
if [[ $script != /* ]]; then
    script=$(command -v -- "$script") || { echo "picker not found: $script" >&2; exit 1; }
fi
[[ -f $script ]] || { echo "picker not found: $script" >&2; exit 1; }
for tool in git jq wt realpath sort; do
    command -v "$tool" >/dev/null 2>&1 || { echo "missing required tool: $tool" >&2; exit 1; }
done
script=$(realpath -e -- "$script")

tmp=$(mktemp -d "${TMPDIR:-/tmp}/rex-worktrees-test.XXXXXX")
tmp=$(realpath -e -- "$tmp")
trap 'rm -rf -- "$tmp"' EXIT
export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_STATE_HOME=$tmp/state
export XDG_CACHE_HOME=$tmp/cache XDG_DATA_HOME=$tmp/data
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0
export LC_ALL=C TERM=xterm-256color
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$tmp/bin"
export REX_TEST_CALLBACKS=$tmp/callbacks.jsonl
: >"$REX_TEST_CALLBACKS"

# Record callback arguments and whether their target directories exist at the
# moment of the callback. This catches close-before-delete, not just CLI wiring.
cat >"$tmp/bin/rex" <<'REX'
#!/usr/bin/env bash
set -euo pipefail
path_exists=false
main_exists=false
for argument in "$@"; do
    case $argument in
        path=*) [[ ! -d ${argument#path=} ]] || path_exists=true ;;
        main=*) [[ ! -d ${argument#main=} ]] || main_exists=true ;;
    esac
done
jq -cn --argjson path_exists "$path_exists" --argjson main_exists "$main_exists" \
    --args '{args: $ARGS.positional, path_exists: $path_exists, main_exists: $main_exists}' \
    -- "$@" >>"$REX_TEST_CALLBACKS"
[[ ${REX_TEST_FAIL:-} != "${2:-}" ]]
REX
chmod +x "$tmp/bin/rex"
export PATH=$tmp/bin:$PATH

fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
same() {
    local label=$1 got=$2 expected=$3
    [[ $got == "$expected" ]] || fail "$label (expected <$expected>, got <$got>)"
    printf 'ok   %s\n' "$label"
}
callback_count() { jq -s 'length' "$REX_TEST_CALLBACKS"; }
last_callback() {
    local action=$1 path=$2 main=${3:-}
    jq -se --arg action "$action" --arg path "$path" --arg main "$main" '
        last | if $action == "worktree_go" then
            .args == ["do", $action, "path=" + $path] and .path_exists
        else
            .args == ["do", $action, "path=" + $path, "main=" + $main]
            and (.path_exists | not) and .main_exists
        end
    ' "$REX_TEST_CALLBACKS" >/dev/null || fail "callback for $action at $path"
}
worktree_path() {
    command wt list --format=json -C "$repo" | jq -er --arg branch "$1" '
        (if type == "array" then .[] else .items[] end)
        | select(.branch == $branch) | .path // .worktree.path
    '
}

repo=$tmp/'repo with spaces'
mkdir -p "$repo"
git -C "$repo" init -q -b main --template=
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name 'Picker Test'
git -C "$repo" config commit.gpgsign false
printf 'initial\n' >"$repo/tracked"
git -C "$repo" add tracked
git -C "$repo" commit -qm init
git -C "$repo" branch stale-branch
# No hooks are configured in the private home or repository. Setup is not a
# picker operation; suppress hook approval only for this fixture creation.
if ! command wt switch --create feat/demo --base main --no-cd --no-hooks -y -C "$repo" >"$tmp/setup.log" 2>&1; then
    cat "$tmp/setup.log" >&2
    fail 'could not create fixture worktree'
fi
worktree=$(worktree_path feat/demo)
worktree=$(realpath -e -- "$worktree")
main_commit=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" update-ref refs/remotes/origin/main "$main_commit"
git -C "$repo" update-ref refs/remotes/origin/remote-tip "$main_commit"
git -C "$repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

expected=$(printf '%s\n' feat/demo main stale-branch)
same 'branch list includes existing worktrees and unmaterialized local branches once' \
    "$(cd "$repo" && bash "$script" branches | sort)" "$expected"
same 'branch list is repository-wide from a linked checkout' \
    "$(cd "$worktree" && bash "$script" branches | sort)" "$expected"
same 'removable excludes main and branches without checkouts' \
    "$(cd "$repo" && bash "$script" removable)" feat/demo
same 'removable includes the current linked checkout' \
    "$(cd "$worktree" && bash "$script" removable)" feat/demo
expected=$(printf '%s\n' feat/demo main origin/main origin/remote-tip stale-branch)
same 'remote candidates are opt-in and symbolic remote HEAD is excluded' \
    "$(cd "$repo" && bash "$script" branches --remotes | sort)" "$expected"
if (cd "$tmp" && bash "$script" removable </dev/null >/dev/null 2>&1); then
    fail 'outside-repository removal was accepted'
fi
printf 'ok   outside-repository removal fails\n'

# Switching an existing branch materializes it without changing its tip.
(cd "$repo" && bash "$script" switch stale-branch --base @)
stale_path=$(worktree_path stale-branch)
same 'existing branch keeps its commit' "$(git -C "$stale_path" rev-parse HEAD)" "$main_commit"
last_callback worktree_go "$stale_path"

# The current HEAD base must come from the calling linked checkout, not main.
printf 'feature\n' >>"$worktree/tracked"
git -C "$worktree" commit -qam 'feature-only commit'
feature_commit=$(git -C "$worktree" rev-parse HEAD)
(cd "$worktree" && bash "$script" switch current-head-child --base @)
current_path=$(worktree_path current-head-child)
same 'new branch uses caller current HEAD' "$(git -C "$current_path" rev-parse HEAD)" "$feature_commit"
last_callback worktree_go "$current_path"
(cd "$repo" && bash "$script" switch explicit-base-child --base main)
explicit_path=$(worktree_path explicit-base-child)
same 'explicit base overrides caller HEAD' "$(git -C "$explicit_path" rev-parse HEAD)" "$main_commit"
last_callback worktree_go "$explicit_path"

(cd "$repo" && bash "$script" switch 'Fix Login Bug' --base @ --slugify)
slug_path=$(worktree_path fix-login-bug)
same 'slugified branch is a real checkout' "$(git -C "$slug_path" branch --show-current)" fix-login-bug
last_callback worktree_go "$slug_path"

# A typed target can be a prefix of an existing branch, but remains exact.
(cd "$repo" && bash "$script" switch current-head --base @)
typed_path=$(worktree_path current-head)
same 'typed name creates an exact branch instead of switching to a prefix match' \
    "$(git -C "$typed_path" branch --show-current)" current-head
last_callback worktree_go "$typed_path"
# ^ must be handed to wt, not treated as a branch to create. The fixture's
# symbolic origin/HEAD identifies main as the default branch.
(cd "$repo" && bash "$script" switch '^')
last_callback worktree_go "$repo"
printf 'ok   worktrunk default-branch shortcut switches to main\n'

before_callbacks=$(callback_count)
before_refs=$(git -C "$repo" for-each-ref --format='%(refname) %(objectname)')
before_worktrees=$(git -C "$repo" worktree list --porcelain)
for invalid in main no-such-removal --force; do
    if (cd "$repo" && bash "$script" remove "$invalid" </dev/null >/dev/null 2>&1); then
        fail "ineligible removal was accepted: $invalid"
    fi
done
same 'ineligible removal sends no callback' "$(callback_count)" "$before_callbacks"
same 'ineligible removal leaves all checkouts intact' \
    "$(git -C "$repo" worktree list --porcelain)" "$before_worktrees"

if (cd "$repo" && bash "$script" switch bad..branch --base @ </dev/null >"$tmp/switch-failure.log" 2>&1); then
    fail 'invalid branch creation unexpectedly succeeded'
fi
same 'failed switch sends no callback' "$(callback_count)" "$before_callbacks"
same 'failed switch changes no refs' "$(git -C "$repo" for-each-ref --format='%(refname) %(objectname)')" "$before_refs"

# Dirty refusal is wt's real safety behavior, not a mocked exit code.
printf 'dirty\n' >>"$worktree/tracked"
if (cd "$repo" && bash "$script" remove feat/demo </dev/null >"$tmp/dirty-removal.log" 2>&1); then
    fail 'dirty removal unexpectedly succeeded'
fi
[[ -d $worktree ]] || fail 'dirty checkout was removed'
same 'dirty checkout keeps its uncommitted contents' "$(tail -n1 "$worktree/tracked")" dirty
same 'failed removal sends no close callback' "$(callback_count)" "$before_callbacks"
git -C "$worktree" restore tracked

# Remove from the linked checkout itself through an alias. Its branch has a
# feature-only commit, so successful removal may keep that unmerged branch.
ln -s "$worktree" "$tmp/checkout-alias"
(cd "$tmp/checkout-alias" && bash "$script" remove feat/demo)
[[ ! -e $worktree ]] || fail 'successful removal left the checkout behind'
same 'successful removal sends one callback' "$(callback_count)" "$((before_callbacks + 1))"
last_callback worktree_close "$worktree" "$repo"
same 'captured removed identity remains normalizable' "$(bash "$script" normalize "$worktree")" "$worktree"
[[ -d $repo ]] || fail 'main checkout was removed'
printf 'ok   successful removal closes canonical checkout only after deletion\n'

# A failed Rex open is reported, but does not roll back a successful wt switch.
if (cd "$repo" && REX_TEST_FAIL=worktree_go bash "$script" switch callback-failure --base @ </dev/null >"$tmp/callback-failure.log" 2>&1); then
    fail 'Rex open failure was not reported'
fi
callback_failure_path=$(worktree_path callback-failure)
[[ -d $callback_failure_path ]] || fail 'Rex callback failure lost the created worktree'
last_callback worktree_go "$callback_failure_path"
printf 'ok   Rex callback failure leaves the successfully created checkout intact\n'

# Forge metadata is the network boundary; checkout creation and repeat lookup
# still use real Worktrunk and Git. A PR branch must not inherit caller HEAD.
cat >"$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
if [[ ${PR_LOOKUP_FAIL:-} == 1 ]]; then
    echo 'PR lookup failed' >&2
    exit 1
fi
case ${1:-} in
    repo) printf 'test/fixture\n' ;;
    api)
        printf '{"title":"Review fixture","user":{"login":"test"},"state":"open","head":{"ref":"pr-review","repo":{"name":"fixture","owner":{"login":"test"}}},"base":{"ref":"main","repo":{"name":"fixture","owner":{"login":"test"}}},"html_url":"https://github.com/test/fixture/pull/42"}\n' ;;
    *) exit 1 ;;
esac
GH
chmod +x "$tmp/bin/gh"
git -C "$repo" remote add origin https://github.com/test/fixture.git
git -C "$repo" config "url.file://$repo/.insteadOf" https://github.com/test/fixture
git -C "$repo" branch pr-review "$feature_commit"
git -C "$repo" update-ref refs/remotes/origin/pr-review "$feature_commit"
(cd "$repo" && bash "$script" pr 42)
pr_path=$(worktree_path pr-review)
same 'PR number checks out the PR head, not the caller HEAD' \
    "$(git -C "$pr_path" rev-parse HEAD)" "$feature_commit"
same 'PR checkout leaves caller branch unchanged' "$(git -C "$repo" branch --show-current)" main
last_callback worktree_go "$pr_path"
before_worktrees=$(git -C "$repo" worktree list --porcelain)
(cd "$repo" && bash "$script" pr https://github.com/test/fixture/pull/42)
same 'PR URL reuses the existing checkout' "$(git -C "$repo" worktree list --porcelain)" "$before_worktrees"
last_callback worktree_go "$pr_path"
before_callbacks=$(callback_count)
for invalid in '' 0 --help not-a-pr https://github.com/test/fixture/issues/42; do
    if (cd "$repo" && bash "$script" pr "$invalid" </dev/null >/dev/null 2>&1); then
        fail "invalid PR accepted: $invalid"
    fi
done
if (cd "$repo" && bash "$script" pr </dev/null >/dev/null 2>&1); then
    fail 'PR operation accepted a missing target'
fi
if (cd "$repo" && bash "$script" pr 42 extra </dev/null >/dev/null 2>&1); then
    fail 'wrong PR argument count accepted'
fi
if (cd "$repo" && PR_LOOKUP_FAIL=1 bash "$script" pr 43 </dev/null >/dev/null 2>&1); then
    fail 'failed PR lookup accepted'
fi
same 'invalid or failed PR lookup sends no callback' "$(callback_count)" "$before_callbacks"
same 'invalid or failed PR lookup changes no checkouts' \
    "$(git -C "$repo" worktree list --porcelain)" "$before_worktrees"

# Registry commands are a public filesystem seam used by sessions.lua.
ln -s "$repo" "$tmp/main-alias"
same 'normalize resolves directory aliases' "$(bash "$script" normalize "$tmp/main-alias")" "$repo"
same 'normalize accepts not-yet-existing paths' \
    "$(bash "$script" normalize "$tmp/missing/../future")" "$tmp/future"
scope=test-server-1
registry=$(bash "$script" registry-lock "$scope")
same 'registry keeps the persistent namespace' "$registry" "$XDG_STATE_HOME/rex/worktrunk/$scope"
[[ -d $registry.lock ]] || fail 'registry lock was not created'
if bash "$script" registry-lock "$scope" >/dev/null 2>&1; then
    fail 'contending registry lock succeeded'
fi
if bash "$script" registry-exists "$scope"; then
    fail 'nonexistent registry was reported present'
fi
printf '{}\n' >"$registry/sessions.json"
bash "$script" registry-exists "$scope" || fail 'existing registry was not found'
bash "$script" registry-unlock "$scope"
[[ ! -e $registry.lock ]] || fail 'registry lock remained after unlock'
same 'unlocked registry can be acquired again' "$(bash "$script" registry-lock "$scope")" "$registry"
bash "$script" registry-unlock "$scope"
if bash "$script" registry-lock '../escape' >/dev/null 2>&1; then
    fail 'unsafe registry scope was accepted'
fi
printf 'ok   registry exclusion, persistence and scope validation\n'
printf 'All picker behavior tests passed.\n'
