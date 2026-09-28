# Issues (tickets)

Look up the team UUID and its state UUIDs first (see [../SKILL.md](../SKILL.md) step 3) — `teamId` is the one required field beyond a title, and states are identified by UUID, not name.

## Create

```graphql
mutation CreateIssue($input: IssueCreateInput!) {
  issueCreate(input: $input) {
    success
    issue { id identifier url title state { name } }
  }
}
```

```json
{"input": {
  "teamId": "<team-uuid>",
  "title": "Prevent partial same-currency bill payment matches",
  "description": "Markdown body.\n\nAC:\n- ...",
  "stateId": "<workflow-state-uuid>"
}}
```

Omit `stateId` and Linear picks the team's first Backlog-category state — or the Triage state when the team has Triage enabled. `teamId` is the only field the schema marks required; supply `title` and `description` in practice. Every create input also accepts a client-supplied `id` (UUID v4) that the backend uses instead of generating one, which lets a caller know the id before the call or address the same entity on a retry.

Other `IssueCreateInput` fields, by intent:

| Intent | Fields |
| ------ | ------ |
| People | `assigneeId`, `subscriberIds`, `delegateId` |
| Planning | `priority` (0–4), `estimate`, `dueDate` (`YYYY-MM-DD`), `cycleId`, `projectId`, `projectMilestoneId`, `releaseIds` |
| Classification | `labelIds`, `teamId`, `stateId` |
| Hierarchy | `parentId` (sub-issue), `subIssueSortOrder`, `sortOrder` |
| Templates | `templateId`, `useDefaultTemplate`, `lastAppliedTemplateId` |
| Attribution (OAuth `actor=app` only) | `createAsUser`, `displayIconUrl` |
| Sources | `sourceCommentId`, `referenceCommentId`, `slaStartedAt`, `slaBreachesAt`, `slaType` |

Priority values come from `issuePriorityValues`: `0` No priority, `1` Urgent, `2` High, `3` Medium, `4` Low.

Batch creation: `issueBatchCreate(input: { issues: [IssueCreateInput!]! })`. Do not fan out one mutation per issue.

## Update

```graphql
mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
  issueUpdate(id: $id, input: $input) {
    success
    issue { identifier state { name } assignee { name } labels { nodes { name } } }
  }
}
```

`$id` accepts a UUID or an identifier (`FLOW-1411`).

- `labelIds` **replaces** the full label set; `addedLabelIds` / `removedLabelIds` change it incrementally. The `issueAddLabel(id:, labelId:)` and `issueRemoveLabel(id:, labelId:)` mutations do the same for one label.
- Nullable fields accept `null` to clear: `assigneeId: null` unassigns, `dueDate: null` removes the date, `cycleId: null` pulls the issue out of its cycle.
- Status is a workflow transition, not a boolean: to close, set `stateId` to a state whose `type` is `completed`; to cancel, a `canceled` state; duplicates use the `duplicate` state.
- Archive vs delete: `issueArchive(id:, trash: true)` moves it to trash, `issueUnarchive(id:)` restores, `issueDelete(id:, permanentlyDelete: true)` is irreversible.

Batch update (max 50 ids per call): `issueBatchUpdate(ids: [UUID!]!, input: IssueUpdateInput!)`.

## Comment

```graphql
mutation AddComment($issueId: String!, $body: String!, $parentId: String) {
  commentCreate(input: { issueId: $issueId, body: $body, parentId: $parentId }) {
    success
    comment { id url body }
  }
}
```

- Replies: set `parentId` to the parent comment's id.
- Threads: `commentResolve(id:, resolvingCommentId:)`, `commentUnresolve(id:)`, `commentUpdate(id:, input: { body })`, `commentDelete(id:)`.
- `doNotSubscribeToIssue: true` comments without subscribing the actor; `subscriberIds` adds watchers.
- Comment targets other than issues: `projectId`, `projectUpdateId`, `initiativeId`, `initiativeUpdateId`, `documentContentId`, `postId` — exactly one parent.
- Mentions, images, and collapsible sections use Markdown (see [queries.md](queries.md#markdown-in-text-fields)).

## Relations, subscription, reminders

```graphql
mutation Relate {
  issueRelationCreate(input: { issueId: "<uuid>", relatedIssueId: "<uuid>", type: blocks }) { success }
}
```

```graphql
mutation Subscribe { issueSubscribe(id: "FLOW-1411", userId: "<uuid>") { success } }
```

```graphql
mutation Remind { issueReminder(id: "FLOW-1411", reminderAt: "2026-10-01T09:00:00.000Z") { success } }
```

`IssueRelationType`: `blocks`, `duplicate`, `related`, `similar`. `issueUnsubscribe(id:, userId:)` is the inverse.

## Link an artifact

Use `attachmentCreate` to attach a PR, branch, or external URL; it renders in the issue's link list and can post a comment simultaneously.

```graphql
mutation Attach {
  attachmentCreate(input: {
    issueId: "<uuid>"
    title: "Fix payment matching"
    url: "https://github.com/liveflow-io/accounting/pull/3368"
    subtitle: "acct-3368"
    commentBody: "Opened the PR for this."
  }) { success attachment { id url } }
}
```

`metadata` (a `JSONObject`) and `groupBySource` are available for integrations. To upload a file first, see [uploads-attachments.md](uploads-attachments.md).
