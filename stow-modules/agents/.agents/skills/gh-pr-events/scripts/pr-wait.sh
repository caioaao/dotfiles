#!/usr/bin/env bash
# Poll a pull request and print what changed as JSON lines.
# Default: block until the first (matching) change, print it, exit 0. -f: keep printing.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: pr-wait.sh [-R OWNER/REPO] [-i SECONDS] [-t SECONDS] [-e JQ_FILTER] [-f] [PR]

  PR    number, URL, or branch; omitted = PR of the current branch
  -R    repository (default: current repo)
  -i    poll interval in seconds (default 30)
  -t    give up after this many seconds, exit 124 (default 0 = never)
  -e    jq filter applied to each event; changes it drops don't count, e.g.
        -e 'select(.event == "reviews.added" and .value.state == "APPROVED")'
  -f    follow: keep printing changes instead of exiting after the first batch

stdout: one JSON object per change, e.g.
  {"event":"state","from":"OPEN","to":"MERGED"}
  {"event":"reviews.added","id":"PRR_…","value":{"author":"bob","state":"APPROVED","body":"…"}}
  {"event":"checks.changed","id":"CI / test","from":"IN_PROGRESS","to":"FAILURE"}
EOF
  exit 2
}

interval=30 timeout=0 follow=0 repo=() filter=.
while getopts 'R:i:t:e:fh' opt; do
  case $opt in
    R) repo=(-R "$OPTARG") ;;
    i) interval=$OPTARG ;;
    t) timeout=$OPTARG ;;
    e) filter=$OPTARG ;;
    f) follow=1 ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
(($# <= 1)) || usage
pr=("$@")

fields=state,isDraft,reviewDecision,mergeStateStatus,headRefOid,labels,reviews,comments,statusCheckRollup

# Flatten the PR into scalars plus id-keyed maps so changes can be diffed per item.
normalize='{
  state, isDraft, reviewDecision, mergeStateStatus,
  head: .headRefOid,
  labels: ([.labels[].name] | sort),
  reviews: (.reviews | map({key: .id, value: {author: .author.login, state, body: .body[:300]}}) | from_entries),
  comments: (.comments | map({key: .id, value: {author: .author.login, body: .body[:300]}}) | from_entries),
  checks: (.statusCheckRollup | map(
    if .__typename == "CheckRun"
    then {key: ([.workflowName, .name] | map(select(. != null and . != "")) | join(" / ")),
          value: (if .status == "COMPLETED" then .conclusion else .status end)}
    else {key: .context, value: .state} end) | from_entries)
}'

# Emit one event per changed scalar and per added/removed/changed map entry.
diff='.[0] as $a | .[1] as $b
  | ($b | keys_unsorted[]) as $k
  | if ($b[$k] | type) == "object" then
      ($b[$k] | to_entries[] as $e
        | if ($a[$k] | has($e.key) | not) then {event: "\($k).added", id: $e.key, value: $e.value}
          elif $a[$k][$e.key] != $e.value then {event: "\($k).changed", id: $e.key, from: $a[$k][$e.key], to: $e.value}
          else empty end),
      ($a[$k] | keys[] | select(. as $id | $b[$k] | has($id) | not) | {event: "\($k).removed", id: .})
    elif $a[$k] != $b[$k] then {event: $k, from: $a[$k], to: $b[$k]}
    else empty end'

# ${arr[@]+…} keeps empty arrays safe under `set -u` on macOS's bash 3.2.
snapshot() { gh pr view ${pr[@]+"${pr[@]}"} ${repo[@]+"${repo[@]}"} --json "$fields" --jq "$normalize"; }

jq -n "if false then null | ($filter) else empty end" || { echo "invalid -e filter" >&2; exit 2; }
prev=$(snapshot)
deadline=$((timeout > 0 ? SECONDS + timeout : 0))
echo "watching: $(jq -c '{state, reviewDecision, checks: (.checks | length), reviews: (.reviews | length), comments: (.comments | length)}' <<<"$prev")" >&2

while :; do
  if ((deadline)); then
    ((SECONDS < deadline)) || { echo "timeout after ${timeout}s, no matching change" >&2; exit 124; }
    sleep $((interval < deadline - SECONDS ? interval : deadline - SECONDS))
  else
    sleep "$interval"
  fi
  cur=$(snapshot)
  events=$(jq -cn --argjson a "$prev" --argjson b "$cur" "[\$a, \$b] | ($diff) | ($filter)")
  prev=$cur
  [[ -n $events ]] || continue
  printf '%s\n' "$events"
  ((follow)) || exit 0
done
