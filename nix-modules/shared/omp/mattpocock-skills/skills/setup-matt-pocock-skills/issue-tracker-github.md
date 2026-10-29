# Issue tracker: GitHub

Issues and specs live as GitHub issues. Use `gh`; record the verified owning write target below during setup:

```sh
GH_HOST='<verified-host>'
GH_REPO='<owner>/<repo>'
GH_TARGET="$GH_HOST/$GH_REPO"
```

Every CLI operation uses `--repo "$GH_TARGET"`; every API operation uses `--hostname "$GH_HOST"` and `repos/$GH_REPO`. Resolve fork/upstream ambiguity before writing. Read references elsewhere with their own explicit target, but write only within the authorized owning target. These conventions grant no authority to push, open PRs, or change repository settings.

## Conventions

- **Verify destination**: `gh repo view "$GH_TARGET" --json nameWithOwner,url,hasIssuesEnabled,isArchived,viewerPermission`. Require the confirmed matching identity and usable issues before hosted setup or writes.
- **Create an issue**: `gh issue create --repo "$GH_TARGET" --title "$TITLE" --body-file ticket.md`. Prepare multiline text as a file, not shell-interpolated source. Record the returned real number and URL before linking it.
- **Read an issue / fetch the relevant ticket**: `gh issue view "$N" --repo "$GH_TARGET" --json number,title,body,labels,state,assignees,url` **and** `gh api --hostname "$GH_HOST" --paginate "repos/$GH_REPO/issues/$N/comments?per_page=100"`. `--comments` alone is not a full-body fetch.
- **List issues**: `gh api --hostname "$GH_HOST" --paginate "repos/$GH_REPO/issues?state=open&per_page=100" --jq '[.[] | select(.pull_request == null) | {number,title,body,labels,assignees,state}]'`. Process every page; fetch comments for selected tickets. Apply the configured labels when filtering.
- **Comment**: `gh issue comment "$N" --repo "$GH_TARGET" --body-file comment.md`.
- **Apply / remove a chosen label**: `gh issue edit "$N" --repo "$GH_TARGET" --add-label "$LABEL"` / `--remove-label "$LABEL"`.
- **Required labels**: read all names with `gh api --hostname "$GH_HOST" --paginate "repos/$GH_REPO/labels?per_page=100" --jq '.[].name'`. After setup confirmation, create each missing selected name with `gh label create "$LABEL" --repo "$GH_TARGET" --color 6E7781 --description "$DESCRIPTION"`. Use the actual triage mapping, not its canonical role names; include the five `wayfinder:` labels when that skill is installed. Reuse existing labels unchanged, then re-read to confirm.
- **Resolve / close**: post the durable resolution first with `gh issue comment "$N" --repo "$GH_TARGET" --body-file resolution.md`. Only after that succeeds, run `gh issue close "$N" --repo "$GH_TARGET"`. If either step fails, leave/report the incomplete state rather than claiming resolution.

When a skill says **publish to the issue tracker**, create an issue in this owning target only within the user's authorized scope.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

Only when set to `yes`:

- **Read a PR**: `gh pr view "$N" --repo "$GH_TARGET" --json number,title,body,labels,state,author,url`, plus `gh pr view "$N" --repo "$GH_TARGET" --comments` and `gh pr diff "$N" --repo "$GH_TARGET"`. Fetch any additional paginated discussion needed.
- **List external PRs**: use the REST field `author_association`, which is not a supported `gh pr list --json` field:

  ```sh
  gh api --hostname "$GH_HOST" --paginate \
    "repos/$GH_REPO/pulls?state=open&per_page=100" \
    --jq '[.[] | select(.author_association == "CONTRIBUTOR" or .author_association == "FIRST_TIME_CONTRIBUTOR" or .author_association == "FIRST_TIMER" or .author_association == "NONE") | {number,title,body,labels,user,author_association}]'
  ```

  Process all pages. Exclude maintainer associations (`OWNER`, `MEMBER`, `COLLABORATOR`) and report unknown associations rather than guessing.
- **Comment / label / close**: `gh pr comment "$N" --repo "$GH_TARGET" --body-file resolution.md`, `gh pr edit "$N" --repo "$GH_TARGET" --add-label "$LABEL"` / `--remove-label "$LABEL"`, then `gh pr close "$N" --repo "$GH_TARGET"` only after the resolution comment succeeds.

Issues and PRs share numbers. For an ambiguous reference, read `gh api --hostname "$GH_HOST" "repos/$GH_REPO/issues/$N"` and inspect `pull_request`; do not treat an authentication/network failure as evidence that it is an issue instead of a PR.

## Parentage and blockers

Native parentage groups a ticket under its source issue (a spec or wayfinder map); it does **not** block that ticket. Native blocker edges encode prerequisite work separately. Use the supported native relation without a duplicate prose `Blocked by` list.

- **Attach a native child**: fetch its numeric database ID with `CHILD_ID=$(gh api --hostname "$GH_HOST" "repos/$GH_REPO/issues/$CHILD" --jq .id)`, then `gh api --hostname "$GH_HOST" --method POST "repos/$GH_REPO/issues/$PARENT/sub_issues" -F sub_issue_id="$CHILD_ID"`. Read `gh api --hostname "$GH_HOST" "repos/$GH_REPO/issues/$CHILD/parent"` to confirm. Preserve existing parentage; do not force reparenting.
- **List native children in order**: `gh api --hostname "$GH_HOST" --paginate "repos/$GH_REPO/issues/$PARENT/sub_issues?per_page=100"`.
- **Add a native blocker**: fetch `BLOCKER_ID=$(gh api --hostname "$GH_HOST" "repos/$GH_REPO/issues/$BLOCKER" --jq .id)`, then `gh api --hostname "$GH_HOST" --method POST "repos/$GH_REPO/issues/$CHILD/dependencies/blocked_by" -F issue_id="$BLOCKER_ID"`. The ID is neither the issue number nor `node_id`.
- **Read blockers and live state**: `gh api --hostname "$GH_HOST" --paginate "repos/$GH_REPO/issues/$CHILD/dependencies/blocked_by?per_page=100"`. A child is unblocked only when every returned blocker is closed.

Confirm capability for this host/repository from its API documentation and read endpoints. A failed request is not proof a feature is unsupported: distinguish missing permission, authentication, and transient errors. If native parentage is unavailable, maintain an ordered task list of real child URLs in the parent's body and a `Part of: <parent URL>` line in each child. If native blockers are unavailable, use a `Blocked by: <issue URLs>` line and fetch every referenced issue's current state. An inaccessible or unresolved blocker is not ready. Use each fallback only for its missing capability; parentage never substitutes for blockers.

## Wayfinding operations

- **Map**: create `gh issue create --repo "$GH_TARGET" --title "$TITLE" --body-file map.md --label wayfinder:map`, with Notes / Decisions-so-far / Fog sections. Discover existing maps by reading all open issues above and selecting the exact `wayfinder:map` label.
- **Child**: create `gh issue create --repo "$GH_TARGET" --title "$TITLE" --body-file ticket.md --label "wayfinder:$TYPE"`, where `TYPE` is `research`, `prototype`, `grilling`, or `task`. Attach it to the map using the parentage operation after its real ID exists. Exactly one recognized type label is canonical; do not dispatch from title/body prose.
- **Map updates**: fetch the current full body, preserve other content, append the decision gist + ticket URL to Decisions-so-far (and update the fallback child index if used), then `gh issue edit "$MAP" --repo "$GH_TARGET" --body-file map.md`.
- **Frontier**: list this map's children in native order (or fallback task-list order). Keep only open issues with exactly one recognized `wayfinder:<type>` label, no assignees, and no open blockers from the blocker read above. In the fallback, fetch each listed child and blocker explicitly. Unknown labels, membership, or blocker state require correction, not guessed readiness. First eligible child in map order wins; other maps and unrelated issues are out of scope.
- **Claim**: re-read eligibility, then `gh issue edit "$CHILD" --repo "$GH_TARGET" --add-assignee @me`, the session's first write. Re-read to confirm assignment; if another assignee appeared, stop rather than doing duplicate work.
- **Resolve**: record the answer as a comment, close only after that succeeds, then update the map's Decisions-so-far with the answer gist and durable ticket/comment link. Re-read the ticket and map; complete newly surfaced tickets/links before reporting the wayfinder ticket done.
