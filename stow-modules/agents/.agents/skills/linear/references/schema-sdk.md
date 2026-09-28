# Schema, SDK, and data formats

## Where the truth lives

| Source | What it gives you |
| ------ | ----------------- |
| Live SDL | <https://raw.githubusercontent.com/linear/linear/master/packages/sdk/src/schema.graphql> (~52k lines, all types, descriptions, deprecations) |
| Apollo Studio | <https://studio.apollographql.com/public/Linear-API/variant/current/home> — browse the schema and run queries without logging in |
| Webhook schema explorer | <https://studio.apollographql.com/public/Linear-Webhooks/variant/current/schema/reference/objects> — payload shapes |
| TypeScript SDK | `npm i @linear/sdk`; `new LinearClient({ apiKey })` or `{ accessToken }`, then typed models (`client.viewer`, `client.issue(id)`) and `.nodes`/`.pageInfo` on connections |

Introspection is enabled on the live endpoint, so you can answer schema questions without downloading anything:

```graphql
query InputShape { __type(name: "IssueCreateInput") { inputFields { name type { kind name ofType { name } } } } }
```

```graphql
query Deprecations { __type(name: "Issue") { fields(includeDeprecated: true) { name isDeprecated deprecationReason } } }
```

```graphql
query Roots { __schema { queryType { name } mutationType { name } subscriptionType { name } } }
```

Prefer hand-written narrow documents over SDK convenience methods: SDK getters often over-fetch, and every extra nested connection multiplies query cost.

## Identifiers and scalars

| Kind | Shape | Notes |
| ---- | ----- | ----- |
| `Node.id` | UUID | What mutations take |
| Issue identifier | `FLOW-1411` | Accepted by `issue(id:)` and `issueUpdate(id:)`; a renamed team key keeps resolving, with the old value in `previousIdentifiers` |
| Project identifier | `customIdentifier` / `identifier` | `project(id:)` also accepts the URL identifier |
| Document `slugId` | slug in the URL | Accepted by `documentUpdate(id:)` |
| Client-assigned `id` | your UUID v4 | Every create input accepts one → idempotent creates |

Scalars:

- `DateTime` — ISO-8601 UTC (`2026-09-22T12:53:18.084Z`).
- `TimelessDate` — date-only, `YYYY-MM-DD`; also accepts year shortcuts (`2026`) and ISO-8601 durations evaluated from today (`P2W`, `-P2W1D`).
- `DateTimeOrDuration` — a date or a relative duration, used by date comparators.
- `Duration` — ISO-8601 duration string or an integer in milliseconds.
- `JSON` / `JSONObject` — free-form payloads (`descriptionData`, `metadata`, `templateData`).

## Deprecations and drift

Deprecated fields carry `@deprecated(reason:)` in the SDL — e.g. `Issue.boardOrder` ("use `sortOrder` instead"), `Project.state` ("use project.status instead"), `cycleCreate` ("Cycle creation is not supported"). Read the reason and use the replacement rather than the field; several `Team.*` id fields have also been replaced by object fields.

The `Subscription` root exists alongside `Query` and `Mutation` (currently used for internal live updates); for external near-real-time needs, use webhooks.

## Sync

Mutations return `lastSyncId: Float!`, a monotonically increasing cursor for delta sync. Query with `updatedAt: { gt: <timestamp> }` filters plus `orderBy: updatedAt` and persist the high-water mark; `X-RateLimit` headers keep a long sync under quota.
