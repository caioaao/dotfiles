---
name: notion
description: Read and write Notion via the `ntn` CLI - fetch/create/edit pages as Markdown, query databases (data sources), search by title, and call any public Notion API endpoint. Use whenever the task mentions Notion pages, docs, databases, or a notion.so / app.notion.com URL.
---

# Notion CLI (`ntn`)

`ntn` wraps the Notion public API. Two layers:

- **Typed commands** (`pages`, `datasources`, `files`) - ergonomic, Markdown-first, human/TSV output by default.
- **Raw escape hatch** (`ntn api <path> [inputs]`) - any endpoint, JSON in / JSON out.

Prefer the typed commands. Drop to `ntn api` only for things they do not cover (properties, comments, blocks, databases, users, search).

## Preflight

```bash
ntn doctor      # version, config path, workspace, token source, API access
ntn whoami      # TSV: bot id, bot name, workspace id/name, person id/name/email
```

If auth fails: `ntn login`. Token can be overridden with `NOTION_API_TOKEN`.

Nothing in Notion is visible to the CLI unless the integration/connection has been
granted access to that page or database. "Not found" usually means "not shared", not "does not exist".

## IDs

- Page/database IDs are 32 hex chars, with or without dashes. Both work.
- Notion URLs end in the dashless ID: `.../Some-Title-2a8c7c632ffa805bae3de7763299de93`.
  Extract with `grep -oE '[0-9a-f]{32}' <<<"$url" | tail -1`.
- `ntn datasources query` accepts a full URL. `ntn pages get` does **not** - pass the bare ID.

## Pages (Markdown)

```bash
ntn pages get <page-id>                      # frontmatter (properties) + Markdown body
ntn pages get <page-id> --json               # raw JSON; also exposes unknown_block_ids

ntn pages create --content '# Title\n\nBody'
ntn pages create --parent page:<id> < page.md
ntn pages create --parent data-source:<id> < row.md
ntn pages create                             # no content source in a TTY -> opens $EDITOR

ntn pages edit <page-id> --content '# New body'
ntn pages edit <page-id> < page.md           # replaces page content
ntn pages trash <page-id> --yes
```

Notes:

- `get` output round-trips: `create`/`edit` strip a leading frontmatter block. On `create`,
  frontmatter `title` sets the page title; other frontmatter properties are ignored.
- `edit` **replaces** the whole body. There is no append. Read first, edit locally, write back:
  ```bash
  ntn pages get <id> > /tmp/p.md && $EDITOR /tmp/p.md && ntn pages edit <id> < /tmp/p.md
  ```
- `--parent` accepts `page:<id>`, `database:<id>`, or `data-source:<id>`. Omitting it creates a private page.
- Blocks the Markdown converter cannot render are dropped and stderr warns. Use `--json` and
  inspect `unknown_block_ids`, then `ntn api v1/blocks/<block-id>` for those.
- Never pass `--allow-deleting-content` unless the user explicitly asked to delete child pages/databases.

## Databases / data sources

A database holds one or more *data sources*. Query targets a data source.

```bash
ntn datasources resolve <database-id>            # list data source IDs under a database
ntn datasources query <url|db-id|data-source-id> # first 25 rows, TSV
ntn datasources query <id> --limit 50 --json
ntn datasources query <id> -s 'Due date desc' -s 'Name asc'
ntn datasources query <id> --filter '{"property":"Done","checkbox":{"equals":true}}'
ntn datasources query <id> --filter-file - < filter.json
ntn datasources query <id> --start-cursor <cursor>   # cursor printed on stderr when more remain
```

`--filter` is raw Notion filter JSON, passed through verbatim - see the Notion
"Filter data source entries" reference for shape.

To learn a data source's property names/types before filtering:

```bash
ntn api v1/data_sources/<data-source-id> | jq '.properties | map_values(.type)'
```

## Search by title

No typed command - use the API. Search only matches **titles**, not body text.

```bash
ntn api v1/search query=roadmap page_size:=5 \
  'filter[property]=object' 'filter[value]=page' \
  | jq -r '.results[] | [.id, ([.properties[]|select(.type=="title").title[0].plain_text]|first // "?"), .url] | @tsv'
```

`filter[value]` is `page` or `data_source`. Paginate with `start_cursor=<next_cursor>`.

## Raw API

```bash
ntn api ls                      # every supported endpoint: METHOD  PATH  SUMMARY
ntn api v1/pages --help         # methods + doc links for one endpoint (cheap)
ntn api v1/pages --docs -X POST # full official markdown docs (large)
ntn api v1/pages --spec -X POST # OpenAPI fragment (very large - avoid dumping raw)
```

Input syntax (order of precedence):

| Form | Meaning | Example |
|---|---|---|
| `path:=json` | typed body value | `archived:=true`, `page_size:=100` |
| `name==value` | query param | `page_size==100` |
| `Header:Value` | request header | `Notion-Version:2025-09-03` |
| `path=value` | body string | `parent[page_id]=abc123` |

Nested paths and arrays work: `properties[Name][title][0][text][content]=Hi`.

Method is GET by default, POST when a body is present, and `-X/--method` always wins.
Body must come from exactly one source: stdin, `--data <JSON|@file|@->`, or inline body inputs.

Useful endpoints:

```bash
ntn api v1/users/me
ntn api v1/pages/<page-id>                                  # page object incl. properties
ntn api v1/pages/<page-id> -X PATCH -d '{"properties":{"Status":{"status":{"name":"Done"}}}}'
ntn api v1/blocks/<block-id>/children page_size==100        # walk block tree
ntn api v1/comments block_id==<page-id>
ntn api v1/comments -d '{"parent":{"page_id":"<id>"},"rich_text":[{"text":{"content":"note"}}]}'
```

Responses are single-line JSON - always pipe through `jq` and select fields. Notion
objects are huge; dumping one raw burns context for no benefit.

## Files

```bash
ntn files create < photo.png
ntn files create --filename photo.png --content-type image/png < /tmp/blob
ntn files create --external-url https://example.com/photo.png
ntn files get <upload-id>
ntn files list                 # first page only; pagination not implemented
```

## Output flags

Most typed commands take `--json` (machine) and `--plain` (TSV, no headers). Default is a
human table. Use `--json` whenever piping into `jq`.

## Environment

| Var | Effect |
|---|---|
| `NOTION_API_TOKEN` | overrides stored credentials |
| `NOTION_WORKSPACE_ID` | target a non-default workspace |
| `NOTION_API_VERSION` | pin the `Notion-Version` header |
| `NOTION_KEYRING=0` | file-based auth at `~/.config/notion/auth.json` instead of OS keychain |
| `NOTION_HOME` | CLI state root (config + spec cache) |

## Guardrails

- `pages edit` and `PATCH` requests are destructive and have no undo. Show the user what will
  change before writing.
- `pages trash` needs `--yes` to skip the prompt - do not add it unless deletion was requested.
- Never print `ntn auth token` output into the transcript.
- `workers` and `notion-as-code` subcommands are alpha/beta and gated - ignore unless asked.
