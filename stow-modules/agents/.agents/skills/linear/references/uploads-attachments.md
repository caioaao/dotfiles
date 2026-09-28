# Uploads and attachments

Two distinct things: **attachments** (a link rendered on an issue) and **file uploads** (bytes in Linear's private storage, referenced by URL).

## Markdown auto-upload

The cheapest path: put an image or video URL — or a base64 `data:` URI — in Markdown in `description`, `body`, or `content`. Linear ingests the file into its own storage and rewrites the reference.

```graphql
mutation IssueCreate {
  issueCreate(input: {
    teamId: "<uuid>"
    title: "Crash on import"
    description: "Screenshot:\n\n![alt text](https://example.com/shot.png)"
  }) { success }
}
```

Works for images and video only. Anything else needs a manual upload.

## Manual upload

1. Ask for a signed URL:

```graphql
mutation RequestUpload {
  fileUpload(contentType: "application/pdf", filename: "recon.pdf", size: 20480) {
    success
    uploadFile { uploadUrl assetUrl headers { key value } }
  }
}
```

2. `PUT` the bytes to `uploadFile.uploadUrl`, copying **every** returned header onto that request (plus `Content-Type: <contentType>`).
3. Use `uploadFile.assetUrl` in Markdown, or as the `url` of an `attachmentCreate`.

```bash
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: application/pdf" \
  -H "$KEY1: $VALUE1" \
  --data-binary @recon.pdf
```

`size` must match the real byte length. `makePublic: true` relaxes the auth requirement on the asset; `metaData` (JSON) is stored alongside it. `fileUploadDangerouslyDelete(assetUrl:)` removes an upload.

## Failure modes

| Symptom | Cause |
| ------- | ----- |
| CORS error on the `PUT` | Upload attempted from the browser — Linear's CSP blocks it. Request the signed URL client-side, `PUT` from a server |
| `403` on the `PUT` | Returned headers were dropped (they come as `[{key, value}]`, not an object) |
| `success: false` / no `uploadFile` | Unsupported `contentType` for the workspace, or `size` mismatch |

## Attaching a link to an issue

```graphql
mutation Link { attachmentCreate(input: {
  issueId: "<uuid>"
  title: "Design doc"
  url: "https://notion.so/…"
  iconUrl: "https://…/icon.png"
}) { success attachment { id title url } } }
```

`Attachment` fields: `title`, `url`, `subtitle`, `metadata` (`JSONObject`), `groupBySource`, plus `creator`, `issue`, `sourceType` on read. `attachmentUpdate(id:, input:)` edits one. Linear also has source-specific helpers (`attachmentLinkGitHubPR`, `attachmentLinkSlack`, `attachmentLinkURL`, …) that fill `metadata` for known integrations — prefer them over a bare `attachmentCreate` when linking those services.
