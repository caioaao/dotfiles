---
name: gh-pr-events
description: Wait for or stream GitHub pull request activity with the gh CLI — CI checks finishing, reviews, comments, pushes, merges, label/draft/state changes. Use when asked to watch, monitor, listen to, or block until something happens on a PR, or to receive real pull_request webhook events locally.
---

# Listening to PR events with gh

`gh` has no event-subscription command. Pick the narrowest mechanism that answers the question:

| Need | Mechanism | Push or poll |
|---|---|---|
| CI checks finished / failed | `gh pr checks --watch` | poll (built in) |
| One Actions run finished | `gh run watch` | poll (built in) |
| Any PR activity: review, comment, push, merge, checks, labels | `pr-wait.sh` (this skill) | poll |
| Real webhook payloads (`pull_request`, `pull_request_review`, …) | `gh webhook forward` extension | push |
| Activity across many PRs/repos involving me | `gh api notifications` | poll |

Every command below blocks. In an agent harness, run it as a background/async job with a deadline longer than the expected wait so the result arrives when it exits. Don't busy-loop `gh pr view` yourself.

## 1. CI checks

```bash
gh pr checks [PR] [-R owner/repo] --watch --fail-fast -i 30   # add --required to ignore optional checks
```

Exit 0 = all passed, 1 = a check failed (with `--fail-fast` it exits on the first failure). Without `--watch`, exit 8 = still pending. `PR` is a number, URL, or branch; leave it out to use the current branch's PR.

```bash
gh run watch <run-id> --exit-status --compact -i 30   # one workflow run; run id from `gh run list --branch <b>`
```

## 2. Any PR activity: `pr-wait.sh`

```bash
~/.agents/skills/gh-pr-events/scripts/pr-wait.sh [-R owner/repo] [-i 30] [-t 3600] [-e JQ_FILTER] [-f] [PR]
```

Always call it by that absolute path, since it lives in the skill directory and not in your repo. `bash` cannot run a `skill://` URL.

It snapshots `gh pr view --json` every `-i` seconds (default 30) and diffs consecutive snapshots. By default it prints the first batch of changes and exits 0. `-f` keeps following. `-t` gives up after N seconds and exits 124. Any `gh` failure (auth, network, bad PR) exits non-zero with gh's error. stderr gets a one-line baseline; stdout gets one JSON object per change:

```json
{"event":"state","from":"OPEN","to":"MERGED"}
{"event":"reviewDecision","from":"REVIEW_REQUIRED","to":"APPROVED"}
{"event":"head","from":"aaa…","to":"bbb…"}
{"event":"labels","from":["bug"],"to":["bug","ready"]}
{"event":"reviews.added","id":"PRR_…","value":{"author":"bob","state":"APPROVED","body":"lgtm"}}
{"event":"comments.added","id":"IC_…","value":{"author":"amy","body":"…"}}
{"event":"checks.changed","id":"CI / test","from":"IN_PROGRESS","to":"FAILURE"}
```

Scalar events are `state`, `isDraft`, `reviewDecision`, `mergeStateStatus`, `head` (a new push), and `labels`. Map events are `reviews.*`, `comments.*`, and `checks.*`, each with `.added`, `.changed`, or `.removed`. Check ids are `workflow / job`, or the status context name. Check values are the conclusion once a check completes and its status before that. Bodies are cut to 300 chars, so fetch full text with `gh pr view <PR> --comments`.

Blind spots:
- `comments` covers top-level conversation comments only. Inline review comments show up as `reviews.added`, because each one belongs to a review, but their text is not included. Read them with `gh api repos/{owner}/{repo}/pulls/<PR>/comments`.
- Edits to existing comment bodies appear as `.changed` only when they fall within the first 300 chars.
- Polling cost is one GraphQL request per interval. Don't go below 10s.

To wait for one specific kind of event, pass `-e` with a jq filter that runs on each event. Changes the filter drops don't count, so the script keeps waiting. Don't pipe `-f` output into `head` instead: the pipeline doesn't exit until the script writes again.

```bash
# until someone approves
~/.agents/skills/gh-pr-events/scripts/pr-wait.sh -e 'select(.event == "reviews.added" and .value.state == "APPROVED")' 123
# until merged or closed
~/.agents/skills/gh-pr-events/scripts/pr-wait.sh -e 'select(.event == "state")' 123
# anything except check churn
~/.agents/skills/gh-pr-events/scripts/pr-wait.sh -e 'select(.event | startswith("checks.") | not)' 123
```

## 3. Real webhook events: `gh webhook forward`

```bash
gh extension install cli/gh-webhook   # once
gh webhook forward -R owner/repo -E pull_request,pull_request_review,pull_request_review_comment,issue_comment,check_run
gh webhook forward -O my-org -E '*' -U http://localhost:8080/hook -S "$SECRET"   # org-wide, to a local server
```

- Without `-U`, every payload body goes to stdout followed by a newline, and stderr gets `[LOG] received event "<type>"`. Parse the stream with `jq -c`. The body has no event-type header, so use the stderr log or payload shape (`.action`, `.pull_request`, `.review`) to tell events apart.
- With `-U`, it POSTs to your server and keeps GitHub's headers (`X-GitHub-Event`, `X-Hub-Signature-256` when `-S` is set).
- Requires admin on the repo or org. It creates a temporary dev webhook that goes away when the process exits. Only one forwarder can be active per repo/org at a time, and it is meant for development, not production.
- `issue_comment` fires for PR conversation comments too (the payload has `.issue.pull_request`).

## 4. Notifications (many PRs, involving me)

```bash
gh api notifications -i -q '.[] | select(.subject.type=="PullRequest") | {reason, title: .subject.title, url: .subject.url, updated_at}'
```

Honor the `X-Poll-Interval` response header, which is 60s at the time of writing. For cheap repeat polls, send `-H "If-None-Match: <ETag from the previous response>"`. An unchanged result is `304 Not Modified`, which doesn't count against the rate limit, **but `gh api` exits 1 on 304**. Treat exit 1 together with a `304` status line (under `-i`) as "no change", not as an error.
