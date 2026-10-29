---
name: setup-matt-pocock-skills
description: "Configure this repo for the engineering skills: set up its issue tracker, triage label vocabulary, and domain doc layout. Run once before first use of the other engineering skills."
disable-model-invocation: true
---

# Setup Matt Pocock's Skills

Scaffold the per-repo configuration that the engineering skills assume:

- **Issue tracker**: where issues live (GitHub by default; local markdown is also supported out of the box)
- **Triage labels**: the strings used for the five canonical triage roles
- **Domain docs**: where `GLOSSARY.md`, `GLOSSARY-MAP.md`, and ADRs live, and the consumer rules for reading them

This is a prompt-driven skill, not a deterministic script. Explore, present what you found, confirm with the user, then write.

## Process

### 1. Explore

Look at the current repo to understand its starting state. Read whatever exists; don't assume:

- `git remote -v` and `.git/config`: which hosted repositories do the remotes name? Distinguish the fork, upstream, and the repository that owns this project's work.
- `AGENTS.md` and `CLAUDE.md` at the repo root: does either exist? Is there already an `## Agent skills` section in either?
- `GLOSSARY.md` and `GLOSSARY-MAP.md` at the repo root, plus any per-context glossaries linked by the map
- Legacy `CONTEXT.md` / `CONTEXT-MAP.md` files and their targets: inspect their semantic role using the migration rules below; their names alone do not identify glossaries
- `docs/adr/` and any `src/*/docs/adr/` directories
- `docs/agents/`: does this skill's prior output already exist? Read its tracker destination, label overrides, and request-surface flags; preserve configured choices unless the user changes them.
- `.scratch/`: a sign that a local-markdown issue tracker convention is already in use
- Is the `triage` skill installed? (a `triage` skill folder alongside this one, or `triage` in your available skills.) This decides whether Section B runs at all.
- Is `wayfinder` installed? If so, setup also needs its five `wayfinder:` labels.
- Monorepo signals: a `pnpm-workspace.yaml`, a `workspaces` field in `package.json`, or a populated `packages/*` with its own `src/`. Use these to recommend a layout for new domain docs, not to override an existing bounded-context layout.

Before recommending a hosted tracker, make a read-only lookup of the candidate repository using its explicit host and path. For GitHub, use `gh repo view <host>/<owner>/<repo> --json nameWithOwner,url,hasIssuesEnabled,isArchived,viewerPermission`. For GitLab, use `glab api --hostname <host> projects/<URL-encoded-group-and-project>` and inspect `id`, `path_with_namespace`, `web_url`, issue availability, archive state, and permissions. Verify the returned identity matches the intended remote and the proposed owning write target. A remote URL alone is not evidence that the repository exists or is reachable.

If lookup fails, the identity differs, or issues are unavailable, explain the concrete limitation and recommend local markdown until resolved. Do not create a repository, change remotes, configure credentials, or enable hosted features as part of setup. Recheck the selected target before any hosted write.

### 2. Present findings and ask

Summarise the discovered configuration and decisions needed, without flagging absent glossaries or ADRs. Then take the sections in order. One section, one answer, then the next.

Lead each question with the recommended answer so the user can accept it in a word. Give a one-line explainer only when the choice genuinely branches. Skip Section B entirely when `triage` isn't installed; skip Section C's layout question when exploration already settled the layout, but still inspect legacy files and include any migration in the confirmation draft.

**Section A: Issue tracker.**

> Explainer: The "issue tracker" is where issues live for this repo. Skills like `to-tickets`, `triage`, and `to-spec` read from and write to it. They need to know whether to call `gh issue create`, write a markdown file under `.scratch/`, or follow some other workflow you describe. Pick the place you actually track work for this repo.

Default posture: propose GitHub or GitLab only after the matching repository passed exploration's read-only lookup. In a fork/upstream setup, state which repository will own issues and labels rather than accepting the CLI's inferred default. Otherwise (or if the user prefers), offer:

- **GitHub**: issues live in the repo's GitHub Issues (uses the `gh` CLI)
- **GitLab**: issues live in the repo's GitLab Issues (uses the [`glab`](https://gitlab.com/gitlab-org/cli) CLI)
- **Local markdown**: issues live as files under `.scratch/<feature>/` in this repo (good for solo projects or repos without a remote)
- **Other** (Jira, Linear, etc.): use the existing tracker configuration and available tracker skill; ask only for workflow or scope information that discovery cannot establish

Record the choice and the explicit owning write target (host + repository/project or scoped tracker workspace/project) in `docs/agents/issue-tracker.md`. All commands must target it explicitly; a referenced issue in another repository is not permission to write there. The GitHub and GitLab templates carry a "PRs as a request surface" flag, defaulted **off**. Preserve an existing configured value; for new setup leave it off and don't raise it. A user who wants external PRs in the triage queue can flip the flag in the file later.

**Section B: Triage label vocabulary.** Skip this section entirely if the `triage` skill isn't installed (exploration told you), since an uninstalled skill needs no labels.

If it is installed, ask exactly one question:

> Do you want to keep the [existing, or default for new setup] triage labels? (recommended: **yes**)

The defaults are the five canonical roles, each label string equal to its name: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. For existing configuration, recommend keeping its mapping, not resetting it. On **yes**, keep the existing mapping or write the defaults for a new setup. Only if the user says no, collect overrides so `triage` reuses existing labels instead of creating duplicates.

For a hosted tracker, the selected strings must exist in the owning write target. Inspect its labels, reuse exact matches, and include creation of only missing chosen labels in the confirmation draft. Local markdown records these values as metadata instead of creating hosted labels.

**Section C: Domain docs.** Preserve an existing glossary layout. For new domain docs, default to **single-context** (one `GLOSSARY.md` + `docs/adr/` at the repo root); record this recommendation in the confirmation draft without a separate layout question.

Offer **multi-context** (a root `GLOSSARY-MAP.md` pointing to per-context `GLOSSARY.md` files) only when exploration found monorepo signals. Then confirm which layout they want.

**Legacy migration:** Inspect root and per-context `CONTEXT.md` files, any `CONTEXT-MAP.md`, its targets, and incoming links before proposing moves. Only genuine domain vocabulary glossaries and their maps qualify. Preserve general project context, session memory, specs, and their pointers. Stop and ask the user to resolve mixed or ambiguous content instead of treating it as a glossary.

For qualifying files, draft one atomic cutover to `GLOSSARY.md` / `GLOSSARY-MAP.md`, covering every per-context file, map entry, relative link, reader/writer instruction, and generated pointer in `docs/agents/`, `AGENTS.md`, and `CLAUDE.md`. Remove old-name aliases rather than leaving split consumers. Inspect any pre-existing destination before proposing a move; resolve conflicting content with the user, and explicitly consolidate matching content and references rather than overwriting a file.

Setup writes consumer rules, not empty domain documents. If no glossary exists, proceed silently; create a glossary only when a term is resolved, a map only when actual per-context glossaries need linking, and an ADR directory only when the first decision needs recording.

### 3. Confirm and edit

Show the user a draft of:

- The `## Agent skills` block to add to whichever of `CLAUDE.md` / `AGENTS.md` is being edited (see step 4 for selection rules)
- The contents of `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, and `docs/agents/triage-labels.md` (the last only when `triage` is installed)
- The verified owning write target and the exact missing labels to create there, including any preserved overrides. Make these hosted side effects explicit; confirmation of local file contents alone is not authorization to change another tracker.
- Any legacy glossary migration: classified source and destination files, conflicts requiring resolution, and all affected maps, links, and generated pointers

Let them edit before writing.

### 4. Write

**Pick the file to edit:**

- If `CLAUDE.md` exists, edit it.
- Else if `AGENTS.md` exists, edit it.
- If neither exists, ask the user which one to create; don't pick for them.

Never create `AGENTS.md` when `CLAUDE.md` already exists (or vice versa); always edit the one that's already there.

If an `## Agent skills` block already exists in the chosen file, update its contents in-place rather than appending a duplicate. Don't overwrite user edits to the surrounding sections.

The block:

```markdown
## Agent skills

### Issue tracker

[one-line summary of where issues are tracked]. See `docs/agents/issue-tracker.md`.

### Triage labels

[one-line summary of the label vocabulary]. See `docs/agents/triage-labels.md`.

### Domain docs

[one-line summary of layout: "single-context" or "multi-context"]. See `docs/agents/domain.md`.
```

Include the `### Triage labels` sub-block, and write `docs/agents/triage-labels.md`, only when `triage` is installed and Section B ran. When it isn't, both are omitted.

Then update the docs files using the seed templates in this skill folder as a starting point. Read existing files first, preserve user-authored rules, and show any replacement in the confirmation draft; never silently overwrite existing docs:

- [issue-tracker-github.md](./issue-tracker-github.md): GitHub issue tracker
- [issue-tracker-gitlab.md](./issue-tracker-gitlab.md): GitLab issue tracker
- [issue-tracker-local.md](./issue-tracker-local.md): local-markdown issue tracker
- [triage-labels.md](./triage-labels.md): label mapping (only if `triage` is installed)
- [domain.md](./domain.md): domain doc consumer rules + layout

Apply any confirmed glossary migration as the same cutover as its consumer changes. If classification or destination conflicts remain unresolved, stop that migration rather than leaving half the files renamed or claiming the cutover is complete.

For "other" issue trackers, write `docs/agents/issue-tracker.md` using the discovered workflow and the user's scope. Include supported operations for reading full bodies/comments, creating and listing maps/children, claiming, blockers, and resolution. Native parentage groups tickets under the source issue/map; a blocker edge gates execution. One does not imply the other. Use native relations when available, with no redundant prose blocker list. If a capability is absent, record explicit parent references plus an ordered child index, and explicit blocker references whose current states can be fetched. The frontier is the ordered set of open, unclaimed children whose blockers are all resolved; unknown membership or blocker state is not ready. Persist the answer before closing and then update the map. Discover supported APIs/CLI operations rather than inventing equivalents. For Linear, read the `linear` skill and retain its scoped ID resolution, pagination, GraphQL error checks, authorized write scope, and read-back discipline.

Independently of Section B, when `wayfinder` is installed, include its required labels in the confirmed setup: `wayfinder:map`, `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, and `wayfinder:task`. This requirement still applies when `triage` is absent. For local markdown, use these literal values in `Labels:` metadata rather than creating hosted labels.

After confirmation, create only the missing required labels using the chosen hosted template's label operation (or the other tracker's discovered supported operation). Preserve existing names, colors, and descriptions. Re-read the labels to establish that every selected name exists. If permissions or capabilities prevent creation, report the exact incomplete step rather than claiming setup is complete.

### 5. Done

Tell the user setup is complete only when the confirmed files are written, any confirmed glossary migration and all its consumer updates are complete, and all required hosted labels exist. Name the owning write target and which engineering skills will read the files. Mention they can edit `docs/agents/*.md` directly later; re-running this skill is only necessary if they want to switch issue trackers or restart from scratch. Setup grants no authority to push branches, open PRs, or publish work beyond the explicitly confirmed tracker changes.
