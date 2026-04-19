---
name: kagi-search
description: Web search and content extraction via Kagi Search API. Use for searching documentation, facts, or any web content. Lightweight, no browser required.
---

# Kagi Search

Web search and content extraction using the official Kagi Search API. No browser required.

## Setup

Requires a Kagi account with API access.

1. Log in at https://kagi.com
2. Go to Settings > API > Generate API Key
3. Add to your shell profile (`~/.profile` or `~/.zprofile` for zsh):
   ```bash
   export KAGI_API_KEY="your-api-key-here"
   ```
4. Install dependencies (run once):
   ```bash
   cd {baseDir}
   npm install
   ```

## Search

```bash
{baseDir}/search.js "query"                         # Basic search (5 results)
{baseDir}/search.js "query" -n 10                   # More results (max 20)
{baseDir}/search.js "query" --content               # Include page content as markdown
{baseDir}/search.js "query" -n 3 --content          # Combined options
```

### Options

- `-n <num>` - Number of results (default: 5, max: 20)
- `--content` - Fetch and include page content as markdown

## Extract Page Content

```bash
{baseDir}/content.js https://example.com/article
```

Fetches a URL and extracts readable content as markdown.

## Output Format

```
--- Result 1 ---
Title: Page Title
Link: https://example.com/page
Published: 2024-06-15T00:00:00Z
Snippet: Description from search results
Content: (if --content flag used)
  Markdown content extracted from the page...

--- Result 2 ---
...
```

## When to Use

- Searching for documentation or API references
- Looking up facts or current information
- Fetching content from specific URLs
- Any task requiring web search without interactive browsing
