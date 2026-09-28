# Webhooks

Linear POSTs a JSON payload to your HTTPS URL whenever a subscribed entity is created, updated, or removed. This replaces polling, and reading webhooks requires workspace-admin rights or an `admin`-scoped token.

```graphql
mutation CreateWebhook($input: WebhookCreateInput!) {
  webhookCreate(input: $input) { success webhook { id url enabled secret } }
}
```

```json
{"input": {
  "url": "https://example.com/webhooks/linear",
  "teamId": "<team-uuid>",
  "resourceTypes": ["Issue", "Comment"],
  "label": "issue-sync",
  "enabled": true
}}
```

- Scope the hook to one team with `teamId`, or to every public team with `allPublicTeams: true`. `resourceTypes` is required.
- Wire values are the singular model names: `Issue`, `Attachment`, `Comment`, `IssueLabel`, `Reaction`, `Project`, `ProjectUpdate`, `Document`, `Initiative`, `InitiativeUpdate`, `Cycle`, `Customer`, `User`.
- Linear generates a `secret` when you don't pass one; read it back with `webhook(id:)` or from the create payload, then store it as the signing secret.
- Manage with `webhookUpdate(id:, input:)` (re-enable a disabled hook, change URL/team), `webhookDelete(id:)`, and `webhookRotateSecret(id:)` — rotation takes effect immediately.
- OAuth apps can register a webhook at install time; de-authorization delivers the `OAuthApp revoked` event.

## Payload

```json
{
  "action": "create",
  "type": "Comment",
  "actor": { "id": "…", "type": "user", "name": "Cursor", "email": "…", "url": "…" },
  "createdAt": "2026-09-22T12:53:18.084Z",
  "data": { "id": "…", "body": "…", "issueId": "…", "userId": "…" },
  "url": "https://linear.app/liveflow/issue/FLOW-1411/…#comment-…",
  "updatedFrom": { "body": "previous value" },
  "organizationId": "…",
  "webhookId": "…",
  "webhookTimestamp": 1676056940508
}
```

`action` is `create`, `update`, or `remove`; `updatedFrom` appears on updates and holds the previous values of changed properties (`null` for previously unset ones). `data` mirrors the GraphQL entity.

Headers: `Linear-Delivery` (payload UUID), `Linear-Event` (`Issue`, `Comment`, …), `Linear-Signature`, `Linear-Timestamp` (ms).

## Delivery contract

- Respond `200` within 5 seconds or the delivery counts as failed.
- Failures retry 3 times: after 1 minute, 1 hour, then 6 hours. A persistently failing URL can be disabled and must be re-enabled manually.
- Verify the signature over the **raw request body** before parsing JSON; compare in constant time.

Elixir (this repo's stack):

```elixir
def verify(raw_body, signature) do
  expected =
    :crypto.mac(:hmac, :sha256, signing_secret(), raw_body)
    |> Base.encode16(case: :lower)

  Plug.Crypto.secure_compare(expected, signature)
end
```

Node:

```ts
const signature = createHmac("sha256", process.env.WEBHOOK_SECRET!).update(rawBody).digest("hex");
if (signature !== request.headers.get("linear-signature")) return new Response(null, { status: 400 });
```

In Phoenix, the raw body must survive to the verification step — read it once (`Plug.Conn.read_body/2` caching, or a dedicated plug before `Parsers`), because a re-serialized parsed map will not reproduce the signature.

## Testing

Point a hook at a scratch URL (RequestBin-style), perform the triggering action in Linear, and confirm `Linear-Event` plus a signature that your verifier accepts. Delivery failures and the last error are visible per webhook in Linear's API settings.
