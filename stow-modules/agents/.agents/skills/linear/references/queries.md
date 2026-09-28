# Queries

Read `errors` before `data` (see [../SKILL.md](../SKILL.md)).

## Connection shape

Every list field is a Relay connection. `nodes` is the shortcut; `edges { node cursor }` exists when you need per-item cursors. `pageInfo { hasNextPage endCursor }` is the pagination handle.

```graphql
query Issues {
  issues(first: 10) {
    nodes { id identifier title }
    pageInfo { hasNextPage endCursor }
  }
}
```

Forward pagination (`first`/`after`) is the documented path; the schema also accepts `last`/`before`.

## Pagination loop

```bash
S='skill://linear/scripts/linear-gql.sh'   # or ~/.agents/skills/linear/scripts/linear-gql.sh
after=null
while :; do
  page=$($S -q 'query($after:String){ issues(first:50, after:$after, orderBy:updatedAt) {
      nodes { identifier } pageInfo { hasNextPage endCursor } } }' -v "{\"after\":$after}")
  echo "$page" | jq -r '.data.issues.nodes[].identifier'
  has=$(echo "$page" | jq -r '.data.issues.pageInfo.hasNextPage')
  after=$(echo "$page" | jq '.data.issues.pageInfo.endCursor')
  [ "$has" = "true" ] || break
done
```

Forward pagination (`first`/`after`) is the documented path; the schema also accepts `last`/`before`.

## Ordering

```graphql
query { issues(orderBy: updatedAt, first: 3) { nodes { identifier updatedAt } } }
```

```graphql
query {
  issues(first: 3, sort: [{ priority: { order: Descending } }, { updatedAt: { order: Ascending } }]) {
    nodes { identifier priority updatedAt }
  }
}
```

`sort` takes a list of per-field objects (`createdAt`, `updatedAt`, `priority`, `dueDate`, `estimate`, `project`, `milestone`, `workflowState`, `label`, `assignee`, `team`, `title`, …) each with `{ order: Ascending|Descending }`.

## Single-entity lookups

`issue`, `project`, `document`, `team`, `user`, `cycle`, `comment`, `attachment`, `issueLabel`, `workflowState`, `webhook` all take `id: String!`. For issues and projects the value may be a UUID or an identifier (`FLOW-1411`), and a stale identifier still resolves if the team key was renamed — the issue then reports it under `previousIdentifiers`.

```graphql
{ issue(id: "FLOW-1411") { identifier previousIdentifiers title state { name type } url } }
```

## Traverse instead of re-querying

Most relations are reachable as nested fields, so one request can replace several:

```graphql
{ issue(id: "FLOW-1411") {
    labels { nodes { name } }
    comments(first: 3) { nodes { id body user { name } } }
    attachments(first: 3) { nodes { id title url } }
    documents(first: 3) { nodes { id title } }
    children(first: 3) { nodes { identifier title } }      # sub-issues
    parent { identifier title }
    relations { nodes { type relatedIssue { identifier } } }
} }
```

`viewer` is the authenticated `User`, `organization` the workspace (`urlKey` is the slug in Linear URLs).

## Search

Three options, in order of usefulness:

| Need | Field |
| ---- | ----- |
| Ranked full-text search across the workspace | `searchIssues(term: "period close", teamId:, includeComments:, first:)` → `nodes: [IssueSearchResult]`, also `totalCount` |
| Structured search narrowed by filters | `issues(filter: { searchableContent: { contains: "period" } })` |
| Fuzzy/semantic | `semanticSearch(query:, types:, maxResults:, filters:)` |

`searchIssues` returns `IssueSearchResult` — same fields as `Issue`, plus `metadata`. The older `issueSearch(query:)` field still resolves but returns a plain `IssueConnection`; prefer `searchIssues`.

## Markdown in text fields

`description`, `body`, `content` are Markdown. A resource URL becomes a mention; a fenced block becomes a collapsible section:

```md
https://linear.app/liveflow/profiles/someuser what do you think of
https://linear.app/liveflow/issue/FLOW-1411/example here?

+++ Implementation notes

Hidden until expanded.

+++
```

## Gotchas

- Editing an issue within 3 minutes of creation does not create activity-log entries (Linear treats it as part of creation).
- `Issue.boardOrder` and several `Team.*` fields are `@deprecated` in the schema; use `sortOrder` / the replacement named in the deprecation reason.
