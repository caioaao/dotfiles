# Authentication

Three modes. Pick by who the caller is, not by convenience.

| Mode | Header | Lifetime | Use for |
| ---- | ------ | -------- | ------- |
| Personal API key | `Authorization: <key>` (no `Bearer`) | Until revoked | Your own scripts and one-off automation |
| OAuth 2.0 access token | `Authorization: Bearer <token>` | 24 h, refresh token alongside | Apps acting for other users |
| Client credentials token | `Authorization: Bearer <token>` | 30 days, no refresh token | CI and scheduled server-to-server runs |

`skill://linear/scripts/linear-gql.sh` sends `LINEAR_API_KEY` verbatim as the `Authorization` value, so a personal key works as-is; for OAuth export the full header value instead: `LINEAR_API_KEY="Bearer <token>"`.

Keys are created at <https://linear.app/settings/account/security>; OAuth apps at <https://linear.app/settings/api/applications/new>.

## OAuth 2.0 flow

1. Redirect the user to `https://linear.app/oauth/authorize` with `client_id`, `redirect_uri`, `response_type=code`, `scope` (comma-separated), and a `state` you verify on return. Optional: `prompt=consent` (force the consent screen, useful for multi-workspace), `actor=user|app` (who owns created resources), and PKCE (`code_challenge`, `code_challenge_method=plain|S256`).
2. Linear redirects back with `?code=...&state=...`; reject the request when `state` mismatches.
3. Exchange the code: `POST https://api.linear.app/oauth/token` as `application/x-www-form-urlencoded` with `code`, `redirect_uri`, `client_id`, `client_secret`, `grant_type=authorization_code` (PKCE adds `code_verifier` and may omit the secret). Response carries `access_token`, `refresh_token`, `expires_in` (~24 h), `scope`.
4. Refresh before expiry: same URL with `grant_type=refresh_token`, `refresh_token`, and either basic auth (`Authorization: Basic base64(client_id:client_secret)`) or `client_id` + `client_secret` params. Replaying a refresh within 30 minutes returns the same new token pair, which makes network-failure retries safe.
5. Revoke with `POST https://api.linear.app/oauth/revoke` and `token=<token>` (+ `token_type_hint`); `200` revoked, `400` already revoked, `401` unauthenticated.

## Scopes

| Scope | Grants |
| ----- | ------ |
| `read` | Always present; read the authorizing user's account |
| `write` | Write access, including comments, issues and their attachments |
| `issues:create` | Create issues and their attachments only |
| `comments:create` | Create comments only |
| `timeSchedule:write` | Create and modify time schedules |
| `admin` | Admin-level endpoints — required for webhook read/write and other workspace-admin operations |
| `app:assignable`, `app:mentionable`, … | Agent-specific scopes |

A token with the right role but the wrong scope fails with `FORBIDDEN` and the message `Invalid scope: '<scope>' required` — see [mutations-errors-limits.md](mutations-errors-limits.md).

## Actor: user vs app

`actor=user` (default) attributes created issues, comments, and changes to the authorizing user. `actor=app` attributes them to the application, and lets you pass `createAsUser` / `displayIconUrl` on issues and comments to impersonate an integration identity. App-actor tokens (including client credentials) can access all public teams in the workspace; per-app team access is editable in the app's settings page.

## Client credentials (CI, scheduled automation)

`POST https://api.linear.app/oauth/token` with `grant_type=client_credentials`, `scope`, and authorization via basic auth or `client_id`/`client_secret` params. The tokens are app-actor, valid 30 days, and there is no refresh token — mint a fresh token at the start of each run and treat a `401` as "mint again". Requesting a token with different scopes revokes all existing app tokens for that app, and rotating the client secret invalidates existing client-credentials tokens.

## Secret hygiene

- Read the key from the environment (`LINEAR_API_KEY`); never echo it into logs, commit it, or paste it into a GraphQL document.
- Rotating the client secret invalidates client-credentials tokens but leaves existing user refresh tokens working; rotating the webhook signing secret takes effect immediately, so update consumers in the same change.
- Prefer short-lived OAuth tokens over long-lived keys for anything that runs unattended on someone else's behalf.
