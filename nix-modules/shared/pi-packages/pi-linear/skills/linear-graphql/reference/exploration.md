# Playbook: undocumented use case

Use this when the recipes do not cover the task, or when an operation fails with
a validation error. Each step is one `linear_schema` call; stop as soon as you
can write the operation.

## 1. Find the root field

Call `linear_schema` with `type: "Query"` and `search: "<noun>"`. `search`
filters the root field list. Search the entity noun ("cycle", "milestone",
"favorite", "initiative", "roadmap"). Singular fields take an id; plural fields
are connections taking `filter`/`first`/`after`.

For writes, search the mutation list instead: `type: "Mutation"`,
`search: "milestone"`. Mutation names are `<entity><Verb>`, so searching the
entity noun finds create, update, delete, and archive at once.

**If the task changes a relationship rather than creating an entity, the
mutation belongs to the entity being changed, not to the noun in the task.**
"Move ENG-123 into the active cycle" is not `cycleUpdate`; it is `issueUpdate`
with `cycleId`. Search the update input instead: `type: "IssueUpdateInput"`,
`search: "cycle"` -> `cycleId: String`. Then resolve the id with a read
(`team(id: "ENG") { activeCycle { id } }`).

## 2. Learn the argument types

The output of step 1 shows each field's signature, e.g.

```
  projectMilestones(filter: ProjectMilestoneFilter, first: Int, ...): ProjectMilestoneConnection!
  projectMilestoneCreate(input: ProjectMilestoneCreateInput!): ProjectMilestonePayload!
```

Describe the input or filter type you need: `type: "ProjectMilestoneCreateInput"`,
or `type: "ProjectMilestoneFilter"` with `search: "date"`.

`type` must be the exact, case-sensitive type name. If you are inferring it
rather than copying it from previous output, do step 5 first - a wrong name is
an error, not an empty result.

Required fields are the ones rendered with `!`. Input objects also show default
values.

## 3. Learn the return type

Connections wrap the entity: `XConnection` has `nodes: [X!]!` and `pageInfo`.
Describe the entity, not the connection: `type: "ProjectMilestone"`.

Pick the smallest set of fields that answers the question. Payloads
(`XPayload`) always carry `success` plus the entity.

## 4. Write the smallest query that works

Start with ids and one or two scalar fields, confirm it runs, then add fields.
This keeps errors cheap to diagnose and keeps complexity low.

## 5. If a type name is unknown

Call `linear_schema` with `search: "milestone"` and no `type`.

With no `type`, `search` matches type names across the whole schema and prints
`kind name # description`. Useful when an error message mentions a type you have
never seen.

## Reading the SDL output

```
Issue.comments(first: Int, after: String, filter: CommentFilter): CommentConnection!
```

- `!` means non-null / required
- `[X!]!` is a non-null list of non-null items
- `@deprecated` fields still work but will be removed - avoid them
- enum types list their values; use them verbatim in filters

## Escape hatch: raw introspection

`linear_schema` covers the normal cases. For anything it does not render (for
example, listing every deprecated field, or directives), send introspection
through `linear_query`:

```graphql
query Introspect($name: String!) {
  __type(name: $name) {
    fields(includeDeprecated: true) { name isDeprecated deprecationReason }
  }
}
```

Never request the full `__schema { types { fields { ... } } }` tree - it is
megabytes and will be truncated.

## Verifying against docs

Linear's schema is the source of truth (no API versioning; deprecations are
marked with `@deprecated`). The prose docs live at
https://linear.app/developers - useful for semantics the schema does not
express, such as rate limits, attachment behaviour, and markdown mentions.
