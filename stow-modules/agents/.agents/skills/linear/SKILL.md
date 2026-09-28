---
name: linear
description: Read and change Linear data through its GraphQL API (api.linear.app). Use when querying or searching Linear issues/projects/documents, creating or updating tickets, filing sub-issues, commenting, changing status/assignee/labels, posting project updates, wiring webhooks, uploading files, or diagnosing a Linear API error, rate limit, or missing OAuth scope.
---

# Linear GraphQL API

Endpoint, auth, the request loop, and one reference file per branch. Every GraphQL document in these files was validated against the live schema, and every read-only document with concrete values was executed against `api.linear.app` (workspace `liveflow`) while this was written. Mutations were validated, not executed.

## 1. Send a request

Use the wrapper — it handles JSON encoding, auth, and the error exit code:

```bash
skill://linear/scripts/linear-gql.sh -q '{ viewer { id name email } }'
skill://linear/scripts/linear-gql.sh < query.graphql          # or stdin
skill://linear/scripts/linear-gql.sh -q 'query($n:Int!){ issues(first:$n){ nodes { identifier } } }' -v '{"n":10}'
skill://linear/scripts/linear-gql.sh -H -q '{ viewer { id } }' # + rate-limit headers
```

The wrapper lives in the skill directory, not in your repo: `skill://linear/scripts/linear-gql.sh` is resolved by `bash` to `~/.agents/skills/linear/scripts/linear-gql.sh`. Do not look for a `.agents/skills/...` path under your cwd — there is none. If the internal URL does not resolve, invoke the absolute path `~/.agents/skills/linear/scripts/linear-gql.sh` instead. Needs `LINEAR_API_KEY` — a personal key as-is, or a full header value like `Bearer <token>` — plus `curl` and `jq`; exits 1 when the response carries `errors`.

Raw contract, for language clients, Postman, or a `PUT` upload:

- `POST https://api.linear.app/graphql`, `Content-Type: application/json`, body `{"query": "...", "variables": {...}}`.
- `Authorization: <personal-api-key>` for a personal key; `Authorization: Bearer <token>` for an OAuth access token.
- Introspection is enabled; the whole schema downloads from <https://raw.githubusercontent.com/linear/linear/master/packages/sdk/src/schema.graphql>.

Done when: a JSON body with `data` and no `errors` comes back.

## 2. Read `errors` before `data`

HTTP 200 with a populated `errors` array is the normal failure mode, mutations included — `success` and validation errors can arrive in the same response, so check both. Switch on `extensions.code`; surface `extensions.userPresentableMessage` to a human.

```json
{"errors":[{"message":"Entity not found: Issue","path":["issue"],
  "extensions":{"code":"INPUT_ERROR","statusCode":400,"userError":true,
    "userPresentableMessage":"Could not find referenced Issue."}}],"data":null}
```

Full code table, complexity math, and quota headers: [references/mutations-errors-limits.md](references/mutations-errors-limits.md).

Done when: `errors` is absent or empty, or the code is understood and being handled.

## 3. Resolve identifiers first

Almost every field is team-scoped and takes a UUID. Only `issue(id:)` and a few siblings also accept a human identifier (`FLOW-1411`), and a renamed team key keeps resolving through `previousIdentifiers`. Resolve UUIDs before mutating — never guess them.

```graphql
query Context {
  viewer { id name email }
  organization { id name urlKey }
  teams(first: 20) { nodes { id key name states { nodes { id name type } } } }
}
```

Users: `users(filter: { email: { eq: "person@example.com" } })`. Labels: `issueLabels` (a workspace label has `team: null`). Projects: `projects`. Prerequisites a team needs: `workflowStates`, `cycles`, `labels`.

Done when: every UUID the document needs is a real value read from this workspace.

## 4. Go to the branch

| Task | File |
| ---- | ---- |
| Fetch data: connections, pagination, ordering, nested traversal, search | [references/queries.md](references/queries.md) |
| Build a `filter:` — comparators, `and`/`or`, relation filters, relative dates | [references/filtering.md](references/filtering.md) |
| Create/update/close tickets, comments, labels, sub-issues, relations | [references/issues.md](references/issues.md) |
| Projects, milestones, project updates, documents, initiatives, cycles, labels config | [references/projects-documents.md](references/projects-documents.md) |
| Mutation contract, batch writes, idempotency, error codes, rate/complexity limits | [references/mutations-errors-limits.md](references/mutations-errors-limits.md) |
| Personal key vs OAuth vs client credentials, scopes, refresh, rotation | [references/auth.md](references/auth.md) |
| Webhooks: create, payload shape, signature verification, retries | [references/webhooks.md](references/webhooks.md) |
| Upload files and attach them to issues | [references/uploads-attachments.md](references/uploads-attachments.md) |
| Introspect the schema, SDK, ID/scalar formats, deprecated fields | [references/schema-sdk.md](references/schema-sdk.md) |

## 5. Invariants

- Connections return at most 50 nodes by default; pass `first:` to narrow, then page with `pageInfo.endCursor` as `after`. Query cost multiplies connection children by the page size, so a broad query can trip complexity limits even at one request per hour.
- Archived entities are hidden unless `includeArchived: true`; filter them deliberately with `archivedAt: { null: false }` when you want the archived ones.
- Order by `orderBy: updatedAt` (or `createdAt`), or `sort: [{…}]` for field-level sorts.
- Resolve names to IDs inside the right scope: state and label names repeat across teams.
- Text fields (`description`, `body`, `content`) are Markdown: resource URLs become mentions, `+++ Section title` opens a collapsible block.
- Images served by Linear require authentication — download and self-host them before displaying outside Linear.
- Fetch updates with webhooks; polling is rate-limited and Linear explicitly discourages it.
- Reads are safe. Writes are not: confirm with the human before creating, updating, or deleting in a workspace you were not asked to change.

## 6. Verify

Re-read the entity you changed (or the shape you needed) in a follow-up query and compare field by field. `success: true` alone proves the request was accepted, not that the entity looks the way you intended.

Done when: the read-back shows the intended values, or the failure has a code from step 2 and a next action.
