---
name: linear-graphql
description: Write GraphQL operations for the Linear API using the linear_query, linear_mutate, and linear_schema tools. Covers issue/project/document/comment lookups, filtering, pagination, mutations (create, update, comment, archive), and a playbook for exploring the schema when a use case is not documented here. Use whenever the task touches Linear issues, projects, cycles, docs, or triage.
compatibility: Requires the pi-linear extension and a LINEAR_API_KEY environment variable.
---

# Linear GraphQL

Linear exposes one endpoint (`https://api.linear.app/graphql`) and one schema. The
tools handle transport and auth; you supply the operation.

| Tool | Use for |
|---|---|
| `linear_query` | any read. Refuses `mutation`. |
| `linear_mutate` | any write. Requires `mutation`. |
| `linear_schema` | field/argument/input lookup, rendered as SDL. |

References, load only what the task needs:

- [reference/queries.md](reference/queries.md) - read recipes per entity
- [reference/mutations.md](reference/mutations.md) - write recipes + input gotchas
- [reference/filtering.md](reference/filtering.md) - filter comparators, pagination, dates, sorting
- [reference/exploration.md](reference/exploration.md) - playbook for undocumented use cases

## Rules that always apply

1. **Pass an explicit `first:` on every connection.** Default page size is 50 and
   connections multiply query complexity by that number. A single query over
   10,000 complexity points is rejected outright.
2. **Select only the fields you need.** Each field costs complexity and context.
   `nodes { id identifier title url }` is usually enough to act on.
3. **Use `variables`, not string interpolation.** Values from the user go in the
   `variables` object.
4. **One operation per call.** The tools send no `operationName`, so a document
   with two operations fails. Use aliases to combine two reads into one
   operation instead.
5. **Mutations take ids, not names.** Resolve `teamId`, `stateId`, `labelIds`,
   `assigneeId`, `projectId` with a read first (see reference/queries.md).
6. **`issue(id:)` accepts the human identifier.** `issue(id: "ENG-123")` and
   `issue(id: "<uuid>")` both work. Same for `parentId`, `issueId` on comments
   and attachments.
7. **Confirm before writing.** Say what will change in Linear before calling
   `linear_mutate`, and keep one logical change per mutation document.

## Starter recipes

Everything below is a complete `query` argument for `linear_query`.

### Who am I / my issues

```graphql
query Me {
  viewer {
    id
    name
    email
    assignedIssues(first: 25, filter: { state: { type: { nin: ["completed", "canceled"] } } }) {
      nodes { identifier title url priority state { name type } }
    }
  }
}
```

### One issue, by identifier

```graphql
query Issue($id: String!) {
  issue(id: $id) {
    id
    identifier
    title
    description
    url
    priority
    priorityLabel
    estimate
    state { name type }
    assignee { name email }
    team { key name }
    project { id name }
    labels(first: 20) { nodes { name } }
  }
}
```
variables: `{ "id": "ENG-123" }`

### Issues in a team, filtered

```graphql
query TeamIssues($after: String) {
  issues(
    first: 50
    after: $after
    orderBy: updatedAt
    filter: {
      team: { key: { eq: "ENG" } }
      state: { type: { in: ["unstarted", "started"] } }
    }
  ) {
    nodes { identifier title url updatedAt assignee { name } state { name } }
    pageInfo { hasNextPage endCursor }
  }
}
```

### Full-text search

```graphql
query Search($term: String!) {
  searchIssues(term: $term, first: 20) {
    nodes { identifier title url state { name } }
  }
}
```
`searchIssues` is rate limited to 30 requests/minute. For an exact identifier use
`issue(id:)` instead.

### Project by name, with its docs and milestones

```graphql
query Project($name: String!) {
  projects(filter: { name: { containsIgnoreCase: $name } }, first: 10) {
    nodes {
      id
      name
      url
      status { name type }
      lead { name }
      startDate
      targetDate
      projectMilestones(first: 20) { nodes { id name targetDate } }
      documents(first: 20) { nodes { id title url } }
    }
  }
}
```

### A document

```graphql
query Document($id: String!) {
  document(id: $id) { id title content url project { id name } updatedAt }
}
```
`document(id:)` takes the UUID or the URL slug.

### Comments on an issue

```graphql
query IssueComments($id: String!) {
  issue(id: $id) {
    identifier
    comments(first: 50) {
      nodes { id body createdAt url user { name } }
      pageInfo { hasNextPage endCursor }
    }
  }
}
```

### Create an issue

`linear_mutate`, after resolving `teamId` via `teams(filter: { key: { eq: "ENG" } })`:

```graphql
mutation CreateIssue($input: IssueCreateInput!) {
  issueCreate(input: $input) {
    success
    issue { id identifier url title }
  }
}
```
variables: `{ "input": { "teamId": "<uuid>", "title": "...", "description": "markdown", "priority": 2 } }`

`teamId` is required; `title` is required unless you pass a `templateId`.
Priority: `0` none, `1` urgent, `2` high, `3` medium, `4` low.

### Update an issue

```graphql
mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
  issueUpdate(id: $id, input: $input) { success issue { identifier state { name } } }
}
```
variables: `{ "id": "ENG-123", "input": { "stateId": "<uuid>", "assigneeId": "<uuid>" } }`

`id` takes the identifier, but everything inside `input` takes UUIDs. Statuses
are per team: get `stateId` from `workflowStates(filter: { team: { key: { eq: "ENG" } } })`.

### Comment on an issue

```graphql
mutation Comment($input: CommentCreateInput!) {
  commentCreate(input: $input) { success comment { id url } }
}
```
variables: `{ "input": { "issueId": "ENG-123", "body": "markdown" } }`

`body` is markdown; pasting a Linear issue or profile URL renders as a mention.

## When something fails

| Symptom | Do this |
|---|---|
| "Cannot query field X on type Y" | `linear_schema` with `type: "Y"`, `search: "x"` |
| "Field ... argument ... of type ... is required" | `linear_schema` on the input type, e.g. `IssueCreateInput` |
| "Unknown argument" on a filter | check [reference/filtering.md](reference/filtering.md), then `linear_schema` with `type: "IssueFilter"` |
| `code=RATELIMITED` or complexity error | lower `first:`, drop fields, split the query |
| `success: false` with no error | the entity id was wrong; re-read it |
| Empty result you expected to be non-empty | archived rows are hidden - retry with `includeArchived: true` |

Never retry the same failing operation unchanged. Look up the field or input
type first, then send a corrected operation.

## Undocumented use case

Follow [reference/exploration.md](reference/exploration.md): find the root field,
describe its argument and return types with `linear_schema`, then build the
smallest possible query.
