---
name: pr-unresolved-threads
description: Fetch unresolved review threads from a GitHub PR via `gh api graphql`. Returns thread id, path, line, resolution state, outdated flag, and comments. Use when responding to PR reviews - more reliable than `gh pr view --comments`, which omits resolution state.
---

# PR Unresolved Threads

Fetch the unresolved review threads on a GitHub PR. Output is JSON suitable for piping into downstream review-remediation steps.

## Input

- A PR number (in the current repo) **or** a full PR URL.

## Procedure

1. **Resolve `<owner>`, `<repo>`, `<num>`.**
   - From a URL `https://github.com/<owner>/<repo>/pull/<num>` - parse directly.
   - From a Graphite URL `https://app.graphite.com/github/pr/<owner>/<repo>/<num>...` - parse the same way.
   - From a bare number - derive owner/repo from the current checkout:
     ```bash
     gh repo view --json owner,name -q '.owner.login + "/" + .name'
     ```

2. **Query GraphQL:**
   ```bash
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $num: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $num) {
           reviewThreads(first: 50) {
             nodes {
               id
               isResolved
               isOutdated
               path
               line
               comments(first: 10) {
                 nodes { author { login } body url }
               }
             }
           }
         }
       }
     }
   ' -F owner=<owner> -F repo=<repo> -F num=<num> \
     -q '.data.repository.pullRequest.reviewThreads.nodes
         | map(select(.isResolved == false))'
   ```

3. **Output** the JSON array. Each element has `id`, `isResolved` (always `false` after the filter), `isOutdated`, `path`, `line`, and `comments[]`.

## Notes

- `first: 50` threads / `first: 10` comments-per-thread covers the vast majority of PRs. Bump if a PR has more.
- `isOutdated: true` threads point at code that has since been rewritten - usually safe to skip, but read the comment first.
- Do **not** mark threads resolved from here. Resolution is the user's call.
