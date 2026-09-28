# Mutations, errors, and limits

## Mutation contract

Every write is a top-level mutation taking either `input: <XInput>!` or a scalar id, and returning a payload:

```graphql
mutation { issueUpdate(id: "FLOW-1411", input: { priority: 2 }) { success issue { identifier priority } lastSyncId } }
```

- Payloads carry `success: Boolean!`, the affected object (nullable in some payloads — check it), and `lastSyncId: Float!` for sync ordering.
- **Validation failures do not surface as `success: false`.** They arrive in the top-level `errors` array with an HTTP 200 or 400. Branch on `errors` first, then on `success`.
- Idempotency: no request-id header exists, but every create input accepts a client-supplied `id` (UUID v4) that the backend uses verbatim — set it when a retry must address the same entity.
- Combine independent writes in one document with aliases (`mutation { a: issueCreate(...) {…} b: commentCreate(...) {…} }`) — one round trip, one complexity bill.
- Prefer batch mutations over loops: `issueBatchCreate(input: { issues: [...] })`, `issueBatchUpdate(ids: [UUID!]!, input:)` (≤50 ids per call).

## Error shape and codes

```json
{"errors":[{"message":"…","path":["issue"],"locations":[{"line":1,"column":3}],
  "extensions":{"code":"INPUT_ERROR","type":"invalid input","statusCode":400,
    "userError":true,"userPresentableMessage":"Could not find referenced Issue."}}]}
```

| `extensions.code` | Trigger | Response |
| ----------------- | ------- | -------- |
| `GRAPHQL_VALIDATION_FAILED` | Unknown field, wrong type, a required input field missing (`Field "IssueCreateInput.teamId" of required type "String!" was not provided.`) | HTTP 400, no `data` |
| `INPUT_ERROR` | Referenced entity missing or value rejected (`Entity not found: Issue`) | HTTP 400, `userPresentableMessage` is user-facing copy |
| `AUTHENTICATION_ERROR` | Missing/invalid credentials (`Authentication required, not authenticated`) | HTTP 401 |
| `FORBIDDEN` | Role allows the action but the token lacks the scope (`Invalid scope: 'admin' required`) | HTTP 403 |
| `RATELIMITED` | Request or complexity quota exhausted | HTTP 400 with `errors[].extensions.code = "RATELIMITED"` |

`errors` can arrive alongside partial `data` (a field-level failure nulls its own field). Treat any non-empty `errors` array as failure unless the call is explicitly best-effort.

## Request limits

Read these response headers on every call instead of guessing:

| Header | Meaning |
| ------ | ------- |
| `X-RateLimit-Requests-Limit` / `-Remaining` / `-Reset` | Requests per hour (key: 2500, OAuth app: 5000, unauthenticated: 600/IP) |
| `X-Complexity` | Points this query cost |
| `X-RateLimit-Complexity-Limit` / `-Remaining` / `-Reset` | Complexity points per hour (key: 3,000,000; OAuth app: 2,000,000) |
| `X-RateLimit-Endpoint-*`, `X-RateLimit-Endpoint-Name` | Per-endpoint limits, present only when that endpoint has its own quota |

Quota is per **user** (all of one user's keys share it); unauthenticated quota is per IP.

## Complexity

`1` point per object, `0.1` per property, and a connection multiplies its children by the page size — the `first:` you pass, or the default `50`.

- `{ user(id:) { name } }` → 2 points.
- `{ user(id:) { createdIssues { nodes { id title createdAt } } } }` → 66 points (`1 + 50 + 50 × 3 × 0.1`).
- A single query may not exceed **10,000 points**; it is rejected outright.

Levers: pass explicit small `first:` values, avoid nesting connections inside connections, filter before fetching, and order by `updatedAt` instead of paging the whole dataset.

## Retry and backoff

On `RATELIMITED`, wait until `X-RateLimit-Requests-Reset` / `-Complexity-Reset` (UTC epoch ms) rather than retrying immediately; add jittered exponential backoff for 5xx. Never retry a mutation without an idempotency `id` or a read-back check.

## Avoiding limits altogether

- Register a webhook instead of polling ([webhooks.md](webhooks.md)).
- Fetch only the fields you consume; unneeded nested connections are the main cost driver.
- Write narrow, specific documents per task rather than one broad "fetch everything" query.
