# Write recipes

Send with `linear_mutate`. Naming convention is `<entity><Verb>` (`issueCreate`,
not `createIssue`) and inputs are `<Entity><Verb>Input`. Every payload has
`success` plus the entity, so always select `success` and the ids you need next.

Resolve ids first (reference/queries.md). Mutations never accept names.

## Issues

```graphql
mutation CreateIssue($input: IssueCreateInput!) {
  issueCreate(input: $input) { success issue { id identifier url } }
}
```

```graphql
mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
  issueUpdate(id: $id, input: $input) { success issue { id identifier state { name } } }
}
```

`IssueCreateInput`: `teamId` required, `title` required unless `templateId` is
given. Common fields: `description`
(markdown), `assigneeId`, `stateId`, `priority` (0-4), `estimate`, `labelIds`,
`projectId`, `projectMilestoneId`, `cycleId`, `parentId` (UUID or `ENG-123`),
`dueDate` (`YYYY-MM-DD`), `subscriberIds`, `id` (supply your own UUID v4 to make
the create idempotent).

`IssueUpdateInput` adds `addedLabelIds`, `removedLabelIds`, `trashed`,
`snoozedUntilAt`.

Label semantics: `labelIds` **replaces** the whole set. To add or remove without
reading first, use `addedLabelIds` / `removedLabelIds`, or the dedicated
mutations `issueAddLabel(id:, labelId:)` / `issueRemoveLabel(id:, labelId:)`.

Lifecycle - one per call:

```graphql
mutation Archive { issueArchive(id: "ENG-123") { success } }
```

```graphql
mutation Trash { issueArchive(id: "ENG-123", trash: true) { success } }
```

```graphql
mutation Unarchive { issueUnarchive(id: "ENG-123") { success } }
```

```graphql
mutation Delete { issueDelete(id: "ENG-123") { success } }
```
`issueDelete(permanentlyDelete: true)` is unrecoverable - do not send it without
an explicit request.

Labels, relations, subscriptions - all take ids:

```graphql
mutation AddLabel { issueAddLabel(id: "ENG-123", labelId: "<uuid>") { success } }
```

```graphql
mutation Link($input: IssueRelationCreateInput!) {
  issueRelationCreate(input: $input) { success issueRelation { id type } }
}
```
variables: `{ "input": { "issueId": "<uuid>", "relatedIssueId": "<uuid>", "type": "blocks" } }`
(`type` is `blocks`, `duplicate`, or `related`.)

```graphql
mutation Subscribe { issueSubscribe(id: "ENG-123", userId: "<uuid>") { success } }
```
`issueRemoveLabel(id:, labelId:)` mirrors `issueAddLabel`.

## Comments

```graphql
mutation Comment($input: CommentCreateInput!) {
  commentCreate(input: $input) { success comment { id url } }
}
```
`CommentCreateInput`: `body` (markdown) plus exactly one target - `issueId`
(UUID or `ENG-123`), `projectId`, `projectUpdateId`, `documentContentId`, or
`initiativeId`. `parentId` makes it a thread reply.

Also: `commentUpdate(id:, input:)`, `commentDelete(id:)`.

Mentions: paste the plain Linear URL of an issue or profile into the body and it
renders as an @mention.

## Projects, milestones, documents

```graphql
mutation CreateProject($input: ProjectCreateInput!) {
  projectCreate(input: $input) { success project { id name url } }
}
```
`ProjectCreateInput`: `name` and `teamIds` required. Optional: `description`
(short summary), `content` (markdown body), `leadId`, `memberIds`, `statusId`,
`startDate`, `targetDate` (`YYYY-MM-DD`), `priority`, `labelIds`, `icon`, `color`.

```graphql
mutation UpdateProject($id: String!, $input: ProjectUpdateInput!) {
  projectUpdate(id: $id, input: $input) { success project { id name } }
}
```

```graphql
mutation CreateMilestone($input: ProjectMilestoneCreateInput!) {
  projectMilestoneCreate(input: $input) { success projectMilestone { id name targetDate } }
}
```

```graphql
mutation CreateDocument($input: DocumentCreateInput!) {
  documentCreate(input: $input) { success document { id title url } }
}
```
`ProjectMilestoneCreateInput`: `name`, `projectId` required.
`DocumentCreateInput`: `title` required; attach with `projectId` or `issueId`;
`content` is markdown.

## Attachments

```graphql
mutation Attach($input: AttachmentCreateInput!) {
  attachmentCreate(input: $input) { success attachment { id } }
}
```
`title`, `url`, `issueId` required. The `url` is the idempotency key: creating an
attachment with a url that already exists on that issue updates it instead of
duplicating. `metadata` is a free-form JSON object; `commentBody` posts a linked
comment at the same time.

## Gotchas

- Payload entities are nullable (`IssuePayload.issue`). Check `success` and
  null-guard before dereferencing.
- HTTP 200 with `errors` and partial data is possible; the tool surfaces both.
- Dates: `dueDate`, `startDate`, `targetDate` are date-only (`2026-02-15`).
  `createdAt` on create inputs must be in the past (import use case only).
- Changes made within 3 minutes of creating an issue are folded into the
  creation event and do not appear in the activity log.
- Priority is `0` none, `1` urgent, `2` high, `3` medium, `4` low. Lower number
  means more urgent, except `0`.
- Estimates use the team's estimation scale; there is no global unit.
- Unsure about an input field? `linear_schema` with `type: "IssueUpdateInput"`
  beats guessing.
