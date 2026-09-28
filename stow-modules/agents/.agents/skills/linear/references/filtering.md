# Filtering

Pass `filter:` to any paginated field (`issues`, `projects`, `documents`, `issueLabels`, `workflowStates`, `users`, `comments`, `notifications`, …). The whole filter type is per-entity — the shapes below are from `IssueFilter`; sibling filters repeat the same comparator vocabulary.

## Comparators

Shared by string, numeric, and date fields:

| Comparator | Meaning |
| ---------- | ------- |
| `eq` / `neq` | equals / not equals |
| `in` / `nin` | in / not in a list |

Numeric and date fields add `lt`, `lte`, `gt`, `gte`. String fields add `eqIgnoreCase`, `neqIgnoreCase`, `startsWith`, `startsWithIgnoreCase`, `notStartsWith`, `endsWith`, `notEndsWith`, `contains`, `notContains`, `containsIgnoreCase`, `containsIgnoreCaseAndAccent`. Free-text-ish fields (`searchableContent`) accept only `contains` / `notContains`. Optional fields accept `null: true|false` to test presence.

```graphql
query { issues(filter: { priority: { lte: 2, neq: 0 } }, first: 3) { nodes { identifier priority } } }
```

```graphql
query { issues(filter: { description: { null: true } }, first: 3) { nodes { identifier } } }
```

```graphql
query { issues(filter: { archivedAt: { null: false } }, includeArchived: true, first: 3) { nodes { identifier archivedAt } } }
```

## Logic

Fields are ANDed by default. `or:` takes a list of the same filter type; `and:` exists explicitly. Both nest.

```graphql
query {
  issues(
    first: 3
    filter: {
      or: [ { priority: { eq: 4 } }, { priority: { eq: 0 } } ]
      dueDate: { lte: "2027" }
    }
  ) { nodes { identifier priority dueDate } }
}
```

## Relations

Nested objects filter on the related entity. To-many relations are existential by default (`some`), with `every`, `length`, and `null` available.

```graphql
query { issues(filter: { assignee: { email: { eq: "caio@liveflow.io" } } }, first: 3) { nodes { identifier } } }
```

```graphql
query { issues(filter: { labels: { name: { eq: "Bug" } } }, first: 3) { nodes { identifier } } }
```

```graphql
query { issues(filter: { labels: { some: { name: { in: ["Bug", "Defect"] } } } }, first: 3) { nodes { identifier } } }
```

```graphql
query { issues(filter: { labels: { every: { name: { eq: "Bug" } } } }, first: 3) { nodes { identifier } } }
```

```graphql
query { issues(filter: { labels: { length: { gte: 2 } } }, first: 3) { nodes { identifier } } }
```

```graphql
query { issues(filter: { comments: { body: { contains: "👍" } } }, first: 3) { nodes { identifier } } }
```

```graphql
query { projects(filter: { lead: { name: { startsWith: "Caio" } } }, first: 3) { nodes { name } } }
```

Team scoping is itself a filter: `team: { key: { eq: "FLOW" } }`, or `id: { eq: "<team-uuid>" }` (workspace-level `teams(filter: ...)` also supports `private`, `visibility`, `parent`, `members`).

## Dates and relative time

Date comparators accept ISO-8601 (`2026-09-22`), year shortcuts (`2021`), and ISO-8601 durations evaluated against today: `P2W` (in two weeks), `-P2W` (two weeks ago).

```graphql
query { issues(filter: { dueDate: { lt: "P2W" } }, first: 3) { nodes { identifier dueDate } } }
```

```graphql
query { issues(filter: { completedAt: { gt: "-P2W" } }, first: 3) { nodes { identifier completedAt } } }
```

## Recipe: current work for a team

```graphql
query CurrentWork($key: String!) {
  issues(
    first: 25
    orderBy: updatedAt
    filter: {
      team: { key: { eq: $key } }
      state: { type: { nin: ["completed", "canceled"] } }
    }
  ) {
    nodes { identifier title state { name type } assignee { name } updatedAt }
  }
}
```

`WorkflowState.type` values: `triage`, `backlog`, `unstarted`, `started`, `completed`, `canceled`, `duplicate`. `Project.status.type` is separate (`backlog`, `canceled`, `completed`, `paused`, `planned`, `started`) — read `organization.projectStatuses` for the concrete statuses in a workspace.
