# Filtering, pagination, sorting

## Filter shape

Every collection field takes `filter: <Entity>Filter`. Each key maps to a
comparator object, never a bare value:

```graphql
query Prioritized {
  issues(first: 20, filter: { priority: { lte: 2, neq: 0 } }) {
    nodes { identifier title priority }
  }
}
```

Keys inside one filter object are ANDed. Use `or: [...]` / `and: [...]` for
anything else:

```graphql
query UrgentOrDueSoon {
  issues(first: 20, filter: {
    or: [{ priority: { eq: 1 } }, { dueDate: { lt: "P1W" } }]
  }) {
    nodes { identifier title dueDate }
  }
}
```

## Comparators

| Field kind | Comparators |
|---|---|
| all | `eq`, `neq`, `in`, `nin` |
| numbers, dates | `lt`, `lte`, `gt`, `gte` |
| strings | `eqIgnoreCase`, `neqIgnoreCase`, `contains`, `notContains`, `containsIgnoreCase`, `notContainsIgnoreCase`, `startsWith`, `endsWith`, `notStartsWith`, `notEndsWith` |
| nullable | `null: true` (is null) / `null: false` (is not null) |
| ids | `eq`, `neq`, `in`, `nin` only - no `contains` |

## Relation filters

To-one relations nest their own filter:

```graphql
filter: {
  team: { key: { eq: "ENG" } }
  assignee: { email: { eq: "john@example.com" } }
  state: { type: { in: ["unstarted", "started"] } }
  project: { name: { containsIgnoreCase: "billing" } }
}
```

To-many relations (`labels`, `comments`, `attachments`, `children`,
`subscribers`) match if **any** element matches. Wrap in `some` to say that
explicitly, `every` to require all elements to match, and `length` to count:

```graphql
filter: { labels: { name: { eq: "Bug" } } }              # has a Bug label
filter: { labels: { some: { name: { eq: "Bug" } } } }    # same, explicit
filter: { labels: { every: { name: { neq: "Bug" } } } }  # no Bug label (also matches unlabelled)
filter: { labels: { length: { eq: 0 } } }                # no labels at all
```

There is no `none:` on collection filters - use `every` with a negated
comparator, or `length: { eq: 0 }`.

`null:` belongs to **to-one** relations and nullable scalars, not to collections:

```graphql
filter: { assignee: { null: true } }                     # unassigned
filter: { project: { null: false } }                     # in some project
```

Useful `IssueFilter` keys: `title`, `description`, `number`, `priority`,
`estimate`, `dueDate`, `createdAt`, `updatedAt`, `completedAt`, `canceledAt`,
`startedAt`, `snoozedUntilAt`, `team`, `state`, `assignee`, `creator`,
`subscribers`, `labels`, `project`, `projectMilestone`, `cycle`, `parent`,
`children`, `comments`, `attachments`, `searchableContent`.

`UserFilter` has `email`, `name`, `displayName`, `active`, `admin`, `isMe`.
`WorkflowStateFilter.type` is `triage | backlog | unstarted | started |
completed | canceled | duplicate`.

Anything not listed: `linear_schema` with `type: "IssueFilter"` (or
`ProjectFilter`, `DocumentFilter`, ...).

## Dates

Date fields accept:

- ISO 8601 datetimes: `"2026-02-15T00:00:00Z"`
- shortcuts: `"2026"` means midnight Jan 1 2026
- ISO 8601 durations relative to now: `"P2W"` = in two weeks, `"-P2W"` = two
  weeks ago, `"-P1D"` = yesterday

```graphql
query Recent {
  touchedThisWeek: issues(first: 50, filter: { updatedAt: { gt: "-P7D" } }) {
    nodes { identifier title updatedAt }
  }
  dueWithinTwoWeeks: issues(first: 50, filter: { dueDate: { lt: "P2W" } }) {
    nodes { identifier title dueDate }
  }
}
```

(Two connections in one document need aliases, as above.)

## Pagination

Relay connections. Read `nodes` directly; `edges { node cursor }` is only needed
for per-item cursors.

```graphql
query Page($cursor: String) {
  issues(first: 50, after: $cursor) {
    nodes { identifier title }
    pageInfo { hasNextPage endCursor }
  }
}
```

Loop while `pageInfo.hasNextPage`, passing `endCursor` as `after`. Backwards
paging is `last` / `before`. Omitting `first` defaults to 50 - never rely on it,
since the page size drives query complexity.

## Sorting

`orderBy` is a two-value enum: `createdAt` (default) or `updatedAt`. There is no
direction argument. For anything else, sort client-side after fetching, or
filter tightly enough that order stops mattering. (`sort:` exists on some fields
but is marked internal - do not use it.)

## Archived rows

Hidden by default. Pass `includeArchived: true` on the connection to see them;
`archivedAt` and `trashed` on the entity tell you which is which.

## Complexity budget

Each property costs 0.1, each object 1, and a connection multiplies its
children's cost by its page size (default 50). One query may not exceed 10,000
points. Consequences:

- always set `first:` explicitly, as low as the task allows
- do not nest three connections deep; run two queries instead
- response headers `x-complexity` and `x-ratelimit-complexity-remaining` track
  spend; the tools surface a warning when a budget drops below 10%
