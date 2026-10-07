---
name: linear
description: Read and change Linear data through its GraphQL API (api.linear.app). Use when querying or searching Linear issues/projects/documents, creating or updating tickets, filing sub-issues, commenting, changing status/assignee/labels, posting project updates, wiring webhooks, uploading files, or diagnosing a Linear API error, rate limit, or missing OAuth scope.
---

# Linear GraphQL API

Endpoint, auth, the request loop, and one reference file per branch. Every GraphQL document in these files was validated against the live schema, and every read-only document with concrete values was executed against `api.linear.app` (workspace `liveflow`) while this was written. Mutations were validated, not executed.

## 1. Send a request

Use the wrapper — it handles JSON encoding, auth, and the error exit code:

```bash
~/.agents/skills/linear/scripts/linear-gql.sh -q '{ viewer { id name email } }'
~/.agents/skills/linear/scripts/linear-gql.sh < query.graphql          # or stdin
~/.agents/skills/linear/scripts/linear-gql.sh -q 'query($n:Int!){ issues(first:$n){ nodes { identifier } } }' -v '{"n":10}'
~/.agents/skills/linear/scripts/linear-gql.sh -H -q '{ viewer { id } }' # + rate-limit headers
~/.agents/skills/linear/scripts/linear-gql.sh -r '.data.issue.description' -q '{ issue(id:"FLOW-1411"){ description } }'  # raw Markdown
```

The wrapper lives in the skill directory, not in your repo: always invoke it by the absolute path `~/.agents/skills/linear/scripts/linear-gql.sh` (inside quotes, write `"$HOME/.agents/..."`). Do not look for a `.agents/skills/...` path under your cwd — there is none. Do not execute `skill://linear/scripts/linear-gql.sh`: `read` resolves that URL, but `bash` refuses to run a virtual path (exit 126). Needs `LINEAR_API_KEY` — a personal key as-is, or a full header value like `Bearer <token>` — plus `curl` and `jq`; exits 1 when the response carries `errors`.

**Print Markdown fields with `-r`.** `description`, `body` and `content` arrive as one JSON string with escaped `\n`s, so the default pretty-printed body puts a whole document on a single line, and agent tool output cuts long lines (omp at 768 bytes). The text comes back truncated and you end up fetching it twice. Whenever a selection includes one of these fields, pass `-r FILTER`: the wrapper checks `errors` first, then prints `jq -r FILTER` of the response, so strings come out as raw Markdown and objects as pretty JSON. Delete the Markdown fields from the structured part and print them after it, in the same request:

```bash
~/.agents/skills/linear/scripts/linear-gql.sh -q '{ issue(id:"FLOW-1411"){
    identifier title state { name } children(first:50){ nodes { identifier title } }
    description comments(first:50){ nodes { createdAt user { name } body } } } }' \
  -r '.data.issue | del(.description, .comments), .description,
      (.comments.nodes | sort_by(.createdAt)[] | "--- \(.user.name) \(.createdAt)\n\(.body)")'
```

Use `-r` rather than piping into `jq`: a pipe drops the wrapper's exit status and turns an `errors` response into `null`. With `-r`, an `errors` response prints the full body to stderr and exits 1.

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
