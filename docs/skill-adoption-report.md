# Skill adoption report

Researched 2026-10-28. Compared your maintained skill bodies and relevant support files with `mattpocock/skills@59db609eb1e18aaf59b63284d0e52255aff0c63c`, the upstream head checked during this investigation. Upstream changes considered: August 27–October 27, 2026.

Implementation recorded below in [Implementation and verification](#implementation-and-verification). The recommendations and snapshot citations remain the original investigation record.

## Recommendation

**Keep your curated Nix/Stow installation. Selectively import correctness fixes; do not replace it with upstream's plugin or install another general-purpose workflow.** Your copy already contains most of the interesting capabilities, including `pr`, `retro`, and `implement-spec`. The gaps are mainly operational instructions, stale routing, and a few small evidence-quality improvements.

Your local stack is more specialized than upstream: bounded structured grilling, explicit `/wayfind` session control, facts-only discovery, fresh-context criticism, offline presentations, PR monitoring, Linear, and Datadog integrations. Preserve those boundaries.

This report distinguishes **adopt** (missing source changes), **adapt** (use the principle with local harness constraints), and **use** (already installed). Priority reflects concrete failure risk and fit with your configuration, not measured usage frequency; no session-history usage analysis was performed.

## What was studied

- Vendored engineering, productivity, experimental, and misc skill bodies under [the maintained skill tree](../nix-modules/shared/omp/mattpocock-skills/skills), including tracker templates, wizard helpers, testing/design references, and domain-document formats.
- Custom skills under the [shared agents](../stow-modules/agents/.agents/skills), [omp](../stow-modules/omp/.config/omp/agent/skills), [Pi](../stow-modules/pi/.pi/agent/skills), and [Claude Code](../stow-modules/claude-code/.claude/skills) Stow trees. Datadog and Pi utility suites were assessed as integrations, not competing process frameworks.
- [Nix packaging](../nix-modules/shared/omp/default.nix), [omp package configuration](../stow-modules/omp/.config/omp/agent/config.yml), [Pi package configuration](../stow-modules/pi/.pi/agent/settings.json), and the [wayfinder loop extension](../nix-modules/shared/omp/wayfinder-loop/index.ts).

Below, **S/** means `nix-modules/shared/omp/mattpocock-skills/skills/`. Local `file:line` references identify the inspected snapshot, not permanent line-number guarantees.

## 1. Adopt the operational fixes first

| Priority | Target | Missing behavior and recommendation | Local evidence | Upstream |
| --- | --- | --- | --- | --- |
| High | `wizard/template.sh` | Import the helper-library fixes: safe `.env` quoting/round-tripping, restrictive creation permissions, destination mode/symlink preservation, EOF handling, Readline, visible opener warnings, and parsing the full wizard before prompting. The skill description itself is already current. | `S/wizard/template.sh:69–74,91–136,182–204` | [#1198](https://github.com/mattpocock/skills/pull/1198), [#1237](https://github.com/mattpocock/skills/pull/1237) |
| High | Setup and hosted tracker templates | Require a reachable matching hosted repository; create required labels; fetch issue/PR bodies explicitly; replace unsupported external-PR listing; post resolution comments before closing; make write-target ownership explicit. Update generated per-repo tracker docs where used, not only the seed templates. | `S/setup-matt-pocock-skills/SKILL.md:38–57,102–110`; `issue-tracker-github.md:8–23,34–43` | [#1187](https://github.com/mattpocock/skills/pull/1187), [#1197](https://github.com/mattpocock/skills/pull/1197), [#1228](https://github.com/mattpocock/skills/pull/1228), [#1169](https://github.com/mattpocock/skills/pull/1169) |
| High | `wayfinder` | Restrict maps/tickets to `wayfinder:` labels, write references only after real IDs exist, prohibit research PRs, and dispatch by the ticket's type label rather than inferring type from its body. | `S/wayfinder/SKILL.md:65,114–115,124` | [#1181](https://github.com/mattpocock/skills/pull/1181) |
| High when used | `claude-handoff` | Replace interpolated summary text with a summary file and a shell-safe launch. Keep this Claude-specific; portable `handoff` remains the better shared omp/Pi default. | `S/claude-handoff/SKILL.md:8` | [#1185](https://github.com/mattpocock/skills/pull/1185) |
| Medium | `to-tickets` and tracker conventions | Attach tickets as native sub-issues of the source issue. Keep parentage separate from blocking. Omit redundant prose blockers when native edges already represent them. | `S/to-tickets/SKILL.md:63,86–101` | [#1188](https://github.com/mattpocock/skills/pull/1188) |

**Why these first:** wizard and handoff instructions handle credentials or shell-interpreted text; tracker instructions create durable external state; wayfinder drives a loop you explicitly packaged. These are more consequential than acquiring another planning skill. The defects are visible in source and documented by upstream reports; this investigation did not reproduce them against your credentials or trackers.

Important adaptations:

- Your `/wayfind` extension advances only after `wayfinder_ticket_done`, after the resolution, closure, map update, and newly surfaced tickets are recorded (`wayfinder-loop/index.ts:44–49,265–269`). Preserve that completion signal. Do not replace it with a loop that treats every yielded question as ticket completion.
- Preserve configured label overrides and setup's external-PR surface default of **off** (`S/setup-matt-pocock-skills/SKILL.md:49–57`). An upstream default is not permission to broaden tracker activity.
- The upstream no-research-PR rule is useful. Its added push instruction still needs authorization; do not turn a planning-skill update into permission to publish branches.
- For GitLab users, also import `glab issue list -O json` and concrete map/child/frontier operations. Your local GitLab template already uses note-then-close; that part is not missing (`issue-tracker-gitlab.md:9–12,24,42–44`).
- Your Linear skill already resolves scoped IDs, checks GraphQL errors, handles pagination, limits writes to authorized scope, and reads back changes (`stow-modules/agents/.agents/skills/linear/SKILL.md:12–34,44–101`). Preserve it. Adopt tracker-independent parent/blocker/frontier semantics, not GitHub commands in Linear workflows.

## 2. Import small evidence-quality improvements

These are targeted corrections to existing skills, not a new architecture or testing framework.

| Target | Adopt or adapt | Local gap | Upstream |
| --- | --- | --- | --- |
| `code-review` | Explicitly discover relevant standards sources. Keep separate standards/spec contexts, but collect both results before delivering the review. Use the configured tracker pointer rather than a hard-coded location. | `S/code-review/SKILL.md:13,29,34–36,58–72` | [#1208](https://github.com/mattpocock/skills/pull/1208) |
| `diagnosing-bugs` | If a red test was forced by mutating code or a fixture, prove the intended mutation landed before interpreting the red result. | `S/diagnosing-bugs/SKILL.md:122–128` | [#1209](https://github.com/mattpocock/skills/pull/1209) |
| `tdd` | Give each proposed seam a one-line **catches / misses** note. This makes the existing seam agreement expose integration gaps. | `S/tdd/SKILL.md:20–26` | [#1192](https://github.com/mattpocock/skills/pull/1192) |
| `grilling` | Phrase recommendations so an affirmative answer accepts the recommendation. In the structured UI, mark the recommended option directly; do not reduce every decision to yes/no. | `S/grilling/SKILL.md:10–30` | [#1193](https://github.com/mattpocock/skills/pull/1193) |
| `implement` | Fetch a passed ticket reference and state its title before coding. Explicitly load TDD/review using the host's actual skill mechanism. | `S/implement/SKILL.md:7–15` | [#1196](https://github.com/mattpocock/skills/pull/1196), [#1189](https://github.com/mattpocock/skills/pull/1189) |

For omp here, “foreground reviews” means a joined pair of tasks, not an unsupported foreground flag. Likewise, this harness exposes `read` with `skill://...`, not a literal Claude `Skill` tool. Import the required behavior without introducing tool names the host does not expose. Preserve the host's delegation and verification gates.

The mutation rule is conditional. It does not justify installing mutation-testing infrastructure, forcing mutations on every bug, or rechecking a failure the user already reported simply to establish that it exists.

**Keep your grilling patch.** `S/grilling/SKILL.md:8–16` limits each round to four questions and uses the structured question tool. `default.nix:12–14` explicitly records this customization. Upstream deliberately prefers plain chat and rejects a general hard question cap; its policy is not a reason to discard your per-round UI preference. See [native-question policy](https://github.com/mattpocock/skills/blob/59db609eb1e18aaf59b63284d0e52255aff0c63c/.out-of-scope/native-question-tool.md) and [question-limit rationale](https://github.com/mattpocock/skills/blob/59db609eb1e18aaf59b63284d0e52255aff0c63c/.out-of-scope/question-limits.md).

## 3. Refresh the workflow you already have

### Adapt `implement-spec`; do not install it again

Your copy already has a task graph, frontier concurrency, context pointers, separate worktrees, and a merger agent (`S/implement-spec/SKILL.md:11–29`). Upstream promotion did not add those capabilities to your collection.

Adopt the corrections from [the integration-branch change](https://github.com/mattpocock/skills/commit/153fc1b93de6584562765cdce299324e1ff9e661):

- The deliverable is the integrated specification on one branch, not necessarily a PR.
- Open a draft PR only after the first merge, and only when the tracker uses PR closure or the user asks.
- Confirm each worktree's starting point, use the agreed testing approach, and integrate the latest integration tip before reporting completion.
- Keep one integration owner and the current harness's delegation/check policy. Do not import reset instructions as permission to destroy work.

Your Pi `setup-worktree` already preserves unrelated work, reuses existing resources, and separates workspace creation from moving the current session (`stow-modules/pi/.pi/agent/skills/setup-worktree/SKILL.md:8–23`). It is a useful building block, not something to replace.

### Update `ask-matt` routing

The router lags the skills it describes: it omits the parallel `implement-spec` alternative and `pr`/`retro` closeout, still describes a removed diagnosing post-mortem, and lacks the requirement to read a skill before claiming what it does (`S/ask-matt/SKILL.md:9–11,22–26,42`). Import [routing updates](https://github.com/mattpocock/skills/commit/389f5d27ce88613eff344b5ae0156eb3227dacae), [skill verification](https://github.com/mattpocock/skills/pull/1194), and [post-bug retro routing](https://github.com/mattpocock/skills/pull/1121), while keeping deliberate local skill entries.

### Use existing skills instead of adding competing ones

- **`pr` is already the PR-body format.** Visual summary, before/after evidence, and merge-risk sections already exist (`S/pr/SKILL.md:12–33,156–168`). Fix its mangled component-tree example at `:65–68` from [the promotion commit](https://github.com/mattpocock/skills/commit/a7d038f6bf7f01b516408e95e2fb56e0b338fa6f). Keep it a reference, not an instruction to open a PR or rerun checks while writing prose.
- **`retro` is already current.** It already loads `writing-for-agents`, treats missing guardrails as findings, and sends mechanical violations toward deterministic checks (`S/retro/SKILL.md:11,18–19`). Use it after a substantive session; no source adoption is needed for [#1083](https://github.com/mattpocock/skills/pull/1083). Fresh-eyes asks whether this result is sound; retro asks what would prevent recurrence.
- **Keep the PR lifecycle split.** `gh-pr-events` waits for state changes; `pr-unresolved-threads` retrieves actual unresolved review threads; Datadog's PR/CI skills supply operational evidence. A better PR-body template replaces none of them.
- **Keep facts, criticism, and presentation separate.** Your `discover` collects facts without turning them into a plan; `fresh-eyes` provides independent criticism; `show-me` explains structure; `present` produces offline artifacts. Upstream `research`, `code-review`, and `pr` complement these rather than making them obsolete.

## 4. Migrate glossary naming as one cutover

**Adopt `GLOSSARY.md` / `GLOSSARY-MAP.md`, but not as scattered replacements.** The benefit is clearer purpose and upstream consistency, not new domain-modeling behavior: your existing modeling skill already forbids implementation detail in the glossary (`S/domain-modeling/SKILL.md:60–64`). [Upstream migration](https://github.com/mattpocock/skills/pull/876).

Update the format filename and every reader/writer together:

- `domain-modeling/SKILL.md` and `CONTEXT-FORMAT.md` → `GLOSSARY-FORMAT.md`.
- `tdd`, `diagnosing-bugs`, `codebase-design/DESIGN-IT-TWICE.md`, `improve-codebase-architecture`, and `wait-what`.
- `ask-matt`, `pr`, `triage`, and setup's skill/domain template.
- Actual glossary files and generated pointers in consuming repositories, after inspecting which files are genuinely domain glossaries. Setup's [legacy-file handling](https://github.com/mattpocock/skills/pull/1228) belongs in the same bundle.

Do not rename arbitrary `CONTEXT.md` files. In particular, your custom `context` skill and its box-local context bundle are **not** domain glossaries. Do not rewrite historical citations or pinned source paths. Until the full cutover is ready, the consistent existing convention is safer than half the skills reading a different file.

## 5. Optional, high-fit refinements

### Teaching and portable handoffs

- **`teach`: adopt both small fixes.** Resolve course output paths from the invocation workspace; resolve bundled format links from the skill directory. Vary the correct quiz answer's position. Both are missing at `S/teach/SKILL.md:12–20,110`. The workspace distinction is especially relevant to immutable Nix-packaged references; writing into the skill directory would be inappropriate, although no such failure was reproduced here. [#1183](https://github.com/mattpocock/skills/pull/1183).
- **`handoff`: make the temp path deterministic.** The local instruction only says OS temporary directory (`S/handoff/SKILL.md:8`). Adopt the explicit `$TMPDIR` then `/tmp` resolution, with `%TEMP%` for Windows contexts. Preserve pointer-first summaries and redaction. [#1184](https://github.com/mattpocock/skills/pull/1184).

### Borrow chief-of-staff memory discipline, not its operating policy

Do **not** add the whole experimental `chief-of-staff` skill by default. Its requirement that all work happen in subagents and its mandate to seek environment improvements on every user message conflict with scoped, inline-first work. A skill file also does not establish persistent scheduling support. [Current source](https://github.com/mattpocock/skills/blob/59db609eb1e18aaf59b63284d0e52255aff0c63c/skills/in-progress/chief-of-staff/SKILL.md).

Its [dated, commit-cited memory rules](https://github.com/mattpocock/skills/pull/1304) are worth adapting to your **existing** context bundle:

- Date durable claims; attach repository and commit to code claims.
- Cite primary sources instead of copying them.
- Preserve superseded claims as history, clearly marked, rather than claiming the bundle describes timeless current truth.
- Recheck the relevant source before using a historical claim as a present-day fact.

Your Claude-local `context` skill already supplies a git-tracked, interlinked bundle, authority ordering (ADRs/specs above Linear above bundle), and supersession (`stow-modules/claude-code/.claude/skills/context/SKILL.md:8–10,21–51`). Strengthen that store; do not create a second wiki. Its repository placement alone does not make the skill available in omp or Pi.

## What not to adopt automatically

- **Self-updating upstream plugins:** retain the shared Nix package and explicit updates. omp and Pi already point at that package (`config.yml:10–13`, Pi `settings.json:3–6`). A second install risks duplicates and loses the controlled local patch. Upstream's [installation change](https://github.com/mattpocock/skills/pull/1218) is useful for a different deployment model.
- **Removal of `resolving-merge-conflicts`:** upstream's removal is not evidence that its intent/provenance technique is useless locally. Retain that technique if used, but do not endorse its unconditional “never abort” or “stage everything” language over work-preservation and user authority (`S/resolving-merge-conflicts/SKILL.md:6–14`). [Removal](https://github.com/mattpocock/skills/commit/daa01d8aa68ad5c61b68970ec2018d0ce9567be6).
- **Deletion of frozen misc skills:** `setup-pre-commit`, `scaffold-exercises`, `migrate-to-shoehorn`, and the Claude git-hook setup remain narrow optional tools. Freezing upstream is a maintenance decision, not a mandate to remove useful local copies. Do not treat that git hook as a complete security boundary; upstream's [freeze record](https://github.com/mattpocock/skills/blob/59db609eb1e18aaf59b63284d0e52255aff0c63c/.out-of-scope/frozen-misc-skills.md) documents bypass/fail-open limitations.
- **More architecture/process frameworks:** `codebase-design`, testing references, prototype UI/logic guidance, ADR format, and `writing-for-agents` already match the inspected upstream content. The writing-fragments/shape/beats and remaining experimental utilities also already contain their upstream skill bodies. Leave unchanged content alone.

## Suggested adoption sequence and verification

1. **Operational bundle:** wizard helpers; setup/tracker/ticket corrections; four wayfinder rules; Claude handoff quoting if retained. Preserve `/wayfind` completion semantics and the existing tracker choice.
2. **Behavior bundle:** review discovery/joining, mutation proof, seam tradeoffs, grilling polarity, implementation identity/integration checks, router refresh, and the small PR example fix. Add teaching/temp-path refinements where used.
3. **Convention bundle:** complete glossary cutover after identifying consumer documents. Optionally add dated-claim discipline to the existing context system for a concrete long-running goal.

For a future implementation, prove changed paths rather than merely checking that Markdown parses:

- Exercise wizard helpers against disposable `.env` fixtures containing spaces, quotes, `$`, and multiline-sensitive input; check permissions, symlinks, EOF, and rerun round-trips. No real secrets.
- Exercise tracker publication only in an authorized disposable repository/workspace: correct destination, label creation, native parent/blocker edges, body visibility, and resolution comment preservation.
- Run a controlled `/wayfind` scenario: an unanswered human question must not advance; a fully recorded ticket must advance exactly once; an empty frontier must stop.
- Give review both a standards violation and a spec violation; verify both axes finish before the combined result. For forced-mutation diagnosis, demonstrate an edit that did not land is rejected as evidence.
- Check the glossary migration against a project with an existing glossary and one without; no split writers, broken format links, or premature empty-document creation.

These are proposed acceptance scenarios, **not checks performed by this report**. Implementation should update source under `nix-modules/`/`stow-modules/`, deploy through the existing Nix/Stow path, and exercise the host; never patch `/run/current-system` directly.

## Evidence and limits

Executed during this investigation:

- Queried GitHub's API for upstream head: `59db609eb1e18aaf59b63284d0e52255aff0c63c`, committed October 27.
- Ran `diff -qr nix-modules/shared/omp/mattpocock-skills/skills /run/current-system/sw/share/omp/mattpocock-skills/skills`: **exit 0, no output**. The deployed vendored tree matched the maintained source at observation time.
- Compared actual local/upstream bodies and relevant supporting files. In the 12-skill core comparison, 29 of 39 files matched and 10 differed; that is a scoped count, not a whole-installation statistic.

**Original investigation limit:** No skills, generated wizards, tracker mutations, credential flows, hooks, schedules, or cross-harness discovery were exercised during the investigation above. Source presence and byte identity do not establish successful runtime invocation. No skills or configuration were changed during that investigation.

## Implementation and verification

Implemented 2026-10-28 in the maintained Nix/Stow sources, without commits or changes to the pre-existing omp `config.yml` edit.

### Adopted

- **Operational:** hardened wizard serialization/decoding, private file creation, mode/symlink preservation, EOF, Readline, opener warnings, and whole-script parsing before prompts. Claude handoff now uses a private summary file and shell-safe arguments.
- **Tracking:** setup verifies a reachable matching owning repository; preserves configured labels and default-OFF external request surfaces; confirms missing-label creation. Hosted templates fetch bodies/discussion explicitly, use supported external-request listing, separate native parentage from blocking, and persist resolutions before closure. Local tracking has corresponding hierarchy/blocker/frontier conventions. Wayfinder selects namespaced labels, dispatches by type label, references real IDs, prohibits research PRs, and retains the explicit completion signal.
- **Behavior:** review discovers standards and joins both axes; diagnosis rejects mutations that did not land; TDD seams state catches/misses; structured grilling retains four-question rounds and accepting recommendation polarity. Implementation resolves ticket identity and loads host-native skills. Integrated-spec delivery, PR authorization, worktree bases, latest-tip reconciliation, routing, and the PR component-tree example are updated.
- **Portable refinements:** teaching distinguishes invocation-workspace outputs from bundled format reads and varies correct-answer positions; handoff resolves temporary directories explicitly. The existing Claude context bundle now dates and cites claims, preserves superseded history, and requires current-source rechecks. Conflict resolution preserves provenance while respecting abort authorization and unrelated work.
- **Glossary:** renamed the domain format to `GLOSSARY-FORMAT.md` and migrated all identified domain readers/writers to `GLOSSARY.md` / `GLOSSARY-MAP.md`. Legacy migration classifies content, handles destination conflicts, and updates pointers together. No actual domain glossary files or generated tracker/domain consumers were found in this repository; unrelated context bundles and historical citations remain unchanged.
- **Packaging:** retained the shared Nix package and Stow layout. The package-maintenance comment now points to this curated adoption record instead of suggesting an unrestricted upstream overwrite.

### Exercised evidence

| Surface | Observed result | Boundary |
| --- | --- | --- |
| Wizard helpers | Eight values across new, existing, and symlink destinations survived decode, rerun, and shell-source round trips. Covered spaces, both quote types, inert shell substitutions, backslashes, empty values, and trailing/literal newlines. New files were `0600`; existing `0640` modes and symlinks survived. | Disposable files only; no real secrets. |
| Wizard interaction | EOF stopped all four prompt types; malformed scripts failed before prompting; missing openers produced visible warnings. A real PTY accepted Ctrl-A editing and returned `Xabc`. The complete example ran twice with disposable browser/`gh` substitutes and retained its values. | Browser opening and GitHub secret delivery were substituted, not exercised against live services. |
| `/wayfind` control | Runtime harness observed no advance for an unanswered question, exactly one advance after completion, and stopping on an empty frontier. | Real extension module with only its packaged skill path redirected to maintained source; minimal host API substitutes, not an interactive deployed loop. |
| Tracker instructions | Headless omp rehearsal correctly rejected unreachable/mismatched destinations, preserved custom labels and external-PR OFF, separated parent/blocker edges, honored type labels and real-ID ordering, and required comment-before-close. | Instruction rehearsal with tools disabled; no hosted publication or API mutation. |
| Review and diagnosis | A headless omp review of a disposable committed fixture returned separate Standards and Spec findings for dependency injection and incorrect expiry. The broader behavior rehearsal required joining both axes before delivery. A synthetic red assertion accompanied by an unchanged mutation target was explicitly rejected as mutation-sensitivity evidence. | No production bug or full diagnostic session exercised. |
| Other behavior | Headless omp rehearsal covered seam tradeoffs, grilling polarity/cap, ticket identity, integration ownership/tips/PR policy, teaching paths, temporary paths, memory provenance, and merge safety. | Decision-level rehearsal, not live integrations or a multi-worktree build. |
| Glossary migration | omp migrated a genuine disposable legacy glossary byte-for-byte and updated its pointer; created nothing in an absent-glossary fixture; preserved unrelated `CONTEXT.md` bytes and pathname. Bundled format links resolved; remaining maintained legacy-name references are migration guidance only. | No external consuming repository was modified. |
| Package and repository gates | Built `omp-mattpocock-skills` from the actual Darwin configuration; `diff -qr` against its packaged tree exited 0. `nix flake check --no-build path:.`, Bash syntax, changed-skill bundled-link checks, and Nix LSP diagnostics passed. Claude Stow simulation reported no conflict. | Flake evaluation emitted existing deprecation warnings; the Stow simulation also proposed an unrelated `settings.json.bak` link, so no full restow was applied. No Bash/Markdown language server was available. |

Built package: `/nix/store/gly7sxd633wlx58cknrbqxnsiqxb4x5g-omp-mattpocock-skills`. Verification used `path:.` so the renamed, not-yet-committed format file was included. Temporary fixtures and harnesses were removed after verification.

### Authorization and deployment limits

- **[blocked] Live tracker acceptance:** no authorized disposable GitHub/GitLab/Linear destination was supplied. Actual label creation, native hierarchy/blocker writes, paginated live-body visibility, resolution preservation, and GitLab host/version capabilities remain unverified.
- **[blocked] System activation:** the package was built but no privileged `darwin-rebuild switch`, deployed `/wayfind` interaction, or Pi/Claude cross-harness discovery was performed. Activate through the existing Nix/Stow workflow under the user's deployment authority; never patch `/run/current-system` directly. Avoid an unreviewed full Claude restow because of the unrelated backup-file link noted above.
