# Read recipes

All snippets go in the `query` argument of `linear_query`. Every connection here
passes an explicit `first:` on purpose - see SKILL.md rule 1.

## Root lookup fields

Single-object roots take `id: String!`:

`issue`, `team`, `project`, `projectMilestone`, `document`, `cycle`, `comment`,
`attachment`, `user`, `issueLabel`, `workflowState`, `initiative`.

Which id forms are accepted:

| Field | Accepts |
|---|---|
| `issue(id:)` | UUID or `ENG-123` |
| `project(id:)` | UUID or URL slug |
| `document(id:)` | UUID or slug |
| `cycle(id:)` | UUID or slug |
| everything else | UUID |

Collection roots take `(first, after, filter, orderBy, includeArchived)`:

`issues`, `teams`, `projects`, `projectMilestones`, `documents`, `comments`,
`cycles`, `users`, `issueLabels`, `workflowStates`, `attachments`, `initiatives`.

## Resolving ids for mutations

```graphql
query Ids($teamKey: String!) {
  teams(filter: { key: { eq: $teamKey } }, first: 1) {
    nodes {
      id
      key
      states(first: 30) { nodes { id name type position } }
      labels(first: 100) { nodes { id name } }
      members(first: 100) { nodes { id name email } }
      activeCycle { id number name }
    }
  }
}
```

One call gives `teamId`, `stateId`, `labelIds`, `assigneeId`, `cycleId`.

Standalone variants (one operation per call):

```graphql
query States { workflowStates(filter: { team: { key: { eq: "ENG" } } }, first: 30) { nodes { id name type } } }
```

```graphql
query Labels { issueLabels(filter: { name: { eqIgnoreCase: "bug" } }, first: 5) { nodes { id name } } }
```

```graphql
query UserByEmail($email: String!) { users(filter: { email: { eq: $email } }, first: 1) { nodes { id name } } }
```

`WorkflowState.type` is one of `triage`, `backlog`, `unstarted`, `started`,
`completed`, `canceled`, `duplicate`. Statuses are per team, so a `stateId` from
one team is invalid on another.

## Issues

By team key and number (when you have the identifier split):

```graphql
query ByNumber {
  issues(filter: { team: { key: { eq: "ENG" } }, number: { eq: 123 } }, first: 1) {
    nodes { id identifier title url }
  }
}
```

My open work across teams:

```graphql
query MyOpen {
  issues(
    first: 50
    orderBy: updatedAt
    filter: {
      assignee: { isMe: { eq: true } }
      state: { type: { in: ["triage", "backlog", "unstarted", "started"] } }
    }
  ) {
    nodes { identifier title url priority state { name } team { key } }
    pageInfo { hasNextPage endCursor }
  }
}
```

Triage queue for a team (`state.type` is `triage` until someone accepts the
issue; accepting is an `issueUpdate` with a non-triage `stateId`):

```graphql
query Triage {
  issues(first: 50, filter: { team: { key: { eq: "ENG" } }, state: { type: { eq: "triage" } } }) {
    nodes { identifier title createdAt creator { name } }
  }
}
```

Recently completed (relative dates, see reference/filtering.md):

```graphql
query DoneLastWeek {
  issues(first: 50, filter: { completedAt: { gt: "-P1W" } }) {
    nodes { identifier title completedAt assignee { name } }
  }
}
```

Sub-issues, parent, relations:

```graphql
query Tree($id: String!) {
  issue(id: $id) {
    identifier
    parent { identifier title }
    children(first: 50) { nodes { identifier title state { type } } }
    relations(first: 20) { nodes { type relatedIssue { identifier title } } }
  }
}
```

History (who changed what):

```graphql
query History($id: String!) {
  issue(id: $id) {
    history(first: 50) {
      nodes {
        createdAt
        actor { name }
        fromState { name }
        toState { name }
        fromAssignee { name }
        toAssignee { name }
        fromPriority
        toPriority
        addedLabelIds
        removedLabelIds
      }
      pageInfo { hasNextPage endCursor }
    }
  }
}
```

Attachments (links to PRs, Sentry, etc.):

```graphql
query Attachments($id: String!) {
  issue(id: $id) { attachments(first: 25) { nodes { id title subtitle url source } } }
}
```
Reverse direction: `attachmentsForURL(url: "https://github.com/org/repo/pull/1") { nodes { issue { identifier } } }`.

## Projects

```graphql
query ProjectDetail($id: String!) {
  project(id: $id) {
    id
    name
    description
    content
    url
    health
    progress
    status { name type }
    lead { name }
    startDate
    targetDate
    teams(first: 10) { nodes { key name } }
    issues(first: 50) { nodes { identifier title state { type } } }
    projectMilestones(first: 20) { nodes { id name targetDate } }
    projectUpdates(first: 5) { nodes { body health createdAt user { name } } }
  }
}
```

`Project` has `status`, not `state` (`ProjectFilter.state` is deprecated).
Full-text: `searchProjects(term: $term, first: 10)`.

## Documents

```graphql
query ProjectDocs($projectId: ID!) {
  documents(filter: { project: { id: { eq: $projectId } } }, first: 50, orderBy: updatedAt) {
    nodes { id title url updatedAt creator { name } }
  }
}
```
`Document.content` is markdown. Full-text: `searchDocuments(term: $term)`.

## Cycles

```graphql
query Cycles {
  cycles(filter: { team: { key: { eq: "ENG" } }, isActive: { eq: true } }, first: 5) {
    nodes {
      id
      number
      name
      startsAt
      endsAt
      progress
      issues(first: 50) { nodes { identifier title estimate state { type } } }
    }
  }
}
```

## Reference values

```graphql
query Priorities { issuePriorityValues { priority label } }
```

```graphql
query Limits { rateLimitStatus { kind limits { type allowedAmount remainingAmount reset } } }
```
