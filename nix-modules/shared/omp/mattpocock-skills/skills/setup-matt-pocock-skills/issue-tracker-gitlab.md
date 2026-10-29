# Issue tracker: GitLab

Issues and specs live as GitLab issues. Use [`glab`](https://gitlab.com/gitlab-org/cli); record the verified owning write target during setup:

```sh
GL_HOST='<verified-host>'
GL_REPO='https://<verified-host>/<group>/<project>'
GL_PROJECT_ID='<verified-numeric-project-id>'
```

Every project CLI operation uses `--repo "$GL_REPO"`; every API operation uses `--hostname "$GL_HOST"` and the explicit numeric project ID. Never rely on the current clone's default project in a fork/upstream setup. References elsewhere are read with their own explicit target; writes remain within the authorized owning project. These conventions grant no authority to push, create MRs, or change project settings.

## Conventions

- **Verify destination**: `glab api --hostname "$GL_HOST" "projects/$GL_PROJECT_ID"`; require `path_with_namespace` and `web_url` to match the confirmed remote/write target, with usable issues, a non-archived project, and appropriate permissions. During initial discovery, look up `projects/<URL-encoded-group-and-project>` to obtain this numeric ID.
- **Create an issue**: `glab issue create --repo "$GL_REPO" --title "$TITLE" --description-file ticket.md`. Prepare multiline descriptions in a file. Record the returned real IID and URL before linking it.
- **Read an issue / fetch the relevant ticket**: `glab api --hostname "$GL_HOST" "projects/$GL_PROJECT_ID/issues/$N"` explicitly retrieves `description`, labels, state, and assignees; also fetch `glab api --hostname "$GL_HOST" --paginate "projects/$GL_PROJECT_ID/issues/$N/notes?per_page=100"` for comments. A comments-only view is insufficient.
- **List issues**: `glab issue list --repo "$GL_REPO" -O json --per-page 100 --page "$PAGE"` (open issues by default), with the chosen `--label "$LABEL"` filter where appropriate. Increment `PAGE` from 1 until exhausted. Here `-O json` selects JSON; `-F` selects a different output-format option and is not the issue-list JSON flag.
- **Comment**: `glab issue note "$N" --repo "$GL_REPO" --message "$(cat comment.md)"`. This is a quoted data expansion; never evaluate body text as shell source.
- **Apply / remove labels**: `glab issue update "$N" --repo "$GL_REPO" --label "$LABEL"` / `--unlabel "$LABEL"`.
- **Required labels**: fetch `glab api --hostname "$GL_HOST" --paginate "projects/$GL_PROJECT_ID/labels?per_page=100"` including inherited labels. After setup confirmation, create each missing selected name with `glab label create --repo "$GL_REPO" --name "$LABEL" --color '#6E7781' --description "$DESCRIPTION"`. Use the actual triage mapping, not canonical role names; include the five `wayfinder:` labels when that skill is installed. Reuse existing labels unchanged, then re-read to confirm.
- **Resolve / close**: first `glab issue note "$N" --repo "$GL_REPO" --message "$(cat resolution.md)"`; only after that succeeds, run `glab issue close "$N" --repo "$GL_REPO"`. Closing does not accept a resolution comment. If either step fails, report the incomplete state rather than claiming resolution.

When a skill says **publish to the issue tracker**, create an issue in this owning project only within the user's authorized scope. GitLab uses the per-project issue `iid` for CLI references, not the global database `id`.

## Merge requests as a triage surface

**MRs as a request surface: no.** _(Set to `yes` if this repo treats external merge requests as feature requests; `/triage` reads this flag.)_

Only when set to `yes`:

- **Read an MR**: `glab api --hostname "$GL_HOST" "projects/$GL_PROJECT_ID/merge_requests/$N"` explicitly retrieves its description and labels. Also fetch all notes via `glab api --hostname "$GL_HOST" --paginate "projects/$GL_PROJECT_ID/merge_requests/$N/notes?per_page=100"` and its diff via `glab mr diff "$N" --repo "$GL_REPO"`.
- **List external MRs**: `glab api --hostname "$GL_HOST" --paginate "projects/$GL_PROJECT_ID/merge_requests?state=opened&per_page=100"`. For each author ID, read `glab api --hostname "$GL_HOST" "projects/$GL_PROJECT_ID/members/all/$AUTHOR_ID"` to check direct/inherited membership. Exclude members/owners; treat only a confirmed non-member as external. A fork source is not proof of an external author. Where membership visibility is restricted or lookup fails, report the classification as unknown and obtain an authorized membership lookup rather than guessing.
- **Comment / label / close**: `glab mr note "$N" --repo "$GL_REPO" --message "$(cat resolution.md)"`, `glab mr update "$N" --repo "$GL_REPO" --label "$LABEL"` / `--unlabel "$LABEL"`, then `glab mr close "$N" --repo "$GL_REPO"` only after the resolution note succeeds.

Issues and MRs have separate IID spaces. Keep the reference surface explicit (`#42` issue vs `!42` MR); never infer it from a failed request.

## Parentage and blockers

Native parentage groups tickets under their source issue/map; blocker links gate prerequisite work separately. A related-issue link is not parentage. Use native relations when supported for the chosen work-item types, without redundant prose blockers.

- **Discover native hierarchy**: read this host/version's work-item hierarchy documentation and inspect the GraphQL schema with `glab api --hostname "$GL_HOST" graphql -f query='{ __schema { mutationType { fields { name args { name type { kind name ofType { kind name } } } } } } }'`. Inspect relevant input types through `__type(name: "<discovered-input-type>") { inputFields { name type { kind name ofType { kind name } } } }`, and discover the hierarchy read query as well. Record the supported parent-attachment and paginated child-list queries in this repo's tracker doc before using them; check GraphQL errors and returned hierarchy after mutation. Do not invent a `glab issue` sub-issue command or assume arbitrary issues can parent other issues.
- **Parentage fallback when unavailable**: keep an ordered task list of real child URLs in the source issue/map description and a `Part of: <parent URL>` line in each child. Read the latest full description, preserve its content, and update it with `glab issue update "$PARENT" --repo "$GL_REPO" --description-file parent.md`.
- **Add a native blocker**: `glab api --hostname "$GL_HOST" --method POST "projects/$GL_PROJECT_ID/issues/$CHILD/links" -F target_project_id="$GL_PROJECT_ID" -F target_issue_iid="$BLOCKER" -f link_type=is_blocked_by`. Both issues must be within authorized scope. Native blocking links depend on the project's tier/capability.
- **Read blockers**: `glab api --hostname "$GL_HOST" --paginate "projects/$GL_PROJECT_ID/issues/$CHILD/links?per_page=100"`. Inspect `link_type == "is_blocked_by"` from this child's perspective and the linked issue's state (`opened`/`closed`); `blocks` points the other way and `relates_to` is not a gate.
- **Blocker fallback when unavailable**: use a `Blocked by: <issue URLs>` line in the child's description and fetch each referenced issue's current state. A ticket is unblocked only when all blockers are closed. Native blockers replace this prose list rather than duplicating it.

Distinguish unavailable capability from missing permissions, authentication errors, and transient failures before choosing a fallback. Use each fallback only for its missing capability. Unknown or inaccessible blocker state is not ready.

## Wayfinding operations

- **Map**: `glab issue create --repo "$GL_REPO" --title "$TITLE" --description-file map.md --label wayfinder:map`, with Notes / Decisions-so-far / Fog sections. Find existing maps with `glab issue list --repo "$GL_REPO" --label wayfinder:map -O json --per-page 100 --page "$PAGE"` across all pages.
- **Child**: `glab issue create --repo "$GL_REPO" --title "$TITLE" --description-file ticket.md --label "wayfinder:$TYPE"`, where `TYPE` is `research`, `prototype`, `grilling`, or `task`. After creation, attach the real IID/URL through the discovered native parentage operation or fallback above. Exactly one recognized type label is canonical; never dispatch from title/description prose.
- **Map updates**: fetch the latest full description, preserve other content, append the decision gist + ticket URL to Decisions-so-far (and update the fallback child index if used), then `glab issue update "$MAP" --repo "$GL_REPO" --description-file map.md`.
- **Frontier**: list the map's native children with the discovered paginated query, or read each issue URL in its ordered fallback task list. Fetch full issue state with the scoped issue API above; retain only `opened` children with exactly one recognized `wayfinder:<type>` label and an empty `assignees` array. Read blockers via the links API or fallback references and retain only children with all blockers `closed`. First eligible child in map order wins; never substitute the project's whole open-issue list. Unknown labels, membership, or blocker states require correction, not guessed readiness.
- **Claim**: re-read eligibility, resolve the current username with `glab api --hostname "$GL_HOST" user`, then `glab issue update "$CHILD" --repo "$GL_REPO" --assignee "$USERNAME"` as the session's first write. Re-read to confirm assignment; if another assignee appeared, stop rather than doing duplicate work.
- **Resolve**: persist the answer as a note, close only after the note succeeds, then update Decisions-so-far with the answer gist and durable ticket/note URL. Re-read the ticket and map; complete newly surfaced tickets/links before reporting the wayfinder ticket done.

CLI flags vary by version. If a documented flag is missing, use that subcommand's `--help` and this host's API documentation to establish a supported scoped equivalent before writing; never guess an option.
