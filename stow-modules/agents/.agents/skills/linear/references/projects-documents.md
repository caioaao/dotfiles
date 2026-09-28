# Projects, milestones, updates, documents, cycles, labels

Team-scoping applies exactly as it does for issues. Reads use `projects`, `documents`, `cycles`, `initiatives`, `issueLabels`, `projectStatuses` (all paginated) or the singular `project(id:)`, `document(id:)`, `cycle(id:)`.

## Projects

```graphql
mutation CreateProject($input: ProjectCreateInput!) {
  projectCreate(input: $input) {
    success
    project { id name url status { name type } lead { name } teams { nodes { key } } }
  }
}
```

Required: `name` and `teamIds` (`[String!]!`). Commonly set: `description`, `content` (Markdown overview), `leadId`, `memberIds`, `statusId`, `priority` (0–4), `startDate` / `targetDate` (`TimelessDate`, or a relative duration like `P2W`), `labelIds`, `icon`, `color`.

`statusId` comes from `organization.projectStatuses` (or `team.projectStatuses`); status types are `backlog`, `planned`, `started`, `paused`, `completed`, `canceled`. `projectUpdate(id:, input: ProjectUpdateInput!)` uses the same fields, all optional, including `teamIds` to move the project.

Milestones: `projectMilestoneCreate(input: { projectId, name, targetDate, description })`, then `projectMilestoneUpdate(id:, input:)`; project relation mutations (`projectRelationCreate`) model dependencies between projects.

## Project updates

```graphql
mutation PostUpdate {
  projectUpdateCreate(input: {
    projectId: "<uuid>"
    body: "Markdown status update."
    health: onTrack
  }) { success projectUpdate { id url createdAt } }
}
```

`ProjectUpdateHealthType`: `onTrack`, `atRisk`, `offTrack`. Updates can be archived (`projectUpdateArchive(id:)`); `project.updateReminderFrequency` / `updateRemindersDay` control the reminder cadence.

## Documents

```graphql
mutation CreateDoc {
  documentCreate(input: {
    title: "Period close design"
    content: "# Markdown body"
    projectId: "<uuid>"
    icon: "📄"
  }) { success document { id slugId url title } }
}
```

Only `title` is required. Attach a document to at most one parent: `projectId`, `initiativeId`, `teamId`, `issueId`, `cycleId`, or `releaseId`. `documentUpdate(id:, input:)` also accepts `hiddenAt` and `trashed`. The `id` in a document URL is the slug and is accepted by `documentUpdate`.

## Initiatives

```graphql
mutation CreateInitiative {
  initiativeCreate(input: { name: "Agent platform", description: "…", ownerId: "<uuid>", targetDate: "2026-12-31", status: Active }) {
    success initiative { id name url }
  }
}
```

`InitiativeStatus`: `Active`, `Canceled`, `Completed`, `Planned`, `Proposed`. Initiatives group projects (`project.initiativeToProjects`, `initiativeUpdate.Create`) and update like projects (`initiativeUpdateCreate`, `initiativeUpdateUpdate`).

## Cycles

`cycleCreate` is deprecated ("Cycle creation is not supported") — cycles come from the team's schedule; read them from `team.cycles` / `cycle(id:)`, assign issues with `cycleId`, and shift scheduled cycles with `cycleShiftAll`. A team's active cycle is `team.activeCycle`.

## Labels

```graphql
mutation CreateLabel {
  issueLabelCreate(input: { name: "bug:data", color: "#EB5757", description: "…", teamId: "<uuid>" }) {
    success issueLabel { id name }
  }
}
```

- `teamId: null` creates a workspace-level label (available to every team); with `teamId` set the label belongs to that team. `issueLabels` lists both.
- Group labels: `isGroup: true` plus `groupType: multiSelect|singleSelect`, with children created via `parentId`.
- Lifecycle: `issueLabelUpdate(id:, input:)`, `issueLabelRetire` (hide from pickers), `issueLabelRestore`, `issueLabelDelete`.
- Project labels mirror this with `projectLabelCreate` / `projectLabelUpdate` / `projectRemoveLabel`.

## Notifications and favorites

`notifications(filter: { type: { eq: "issueNewComment" } })` (observed values include `issueNewComment`, `projectUpdateNewComment`; `notificationsUnreadCount` is a scalar field), `notificationSubscriptionCreate(input: { issueId|projectId|customerId|teamId|labelId|cycleId|initiativeId|customViewId, notificationSubscriptionTypes: […] })`, `favoriteCreate(input: { issueId|projectId|documentId|…, parentId })`.
