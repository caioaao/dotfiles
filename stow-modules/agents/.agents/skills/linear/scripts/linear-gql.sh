#!/usr/bin/env bash
# POST a GraphQL document to Linear's API and print the JSON response.
#
# Usage:
#   linear-gql.sh -q '{ viewer { id } }'                 # inline document
#   linear-gql.sh < query.graphql                        # document on stdin
#   linear-gql.sh -q 'query($t:String!){...}' -v '{"t":"ASYS"}'
#   linear-gql.sh -H -q '{ viewer { id } }'              # also print rate-limit headers
#   linear-gql.sh -r '.data.issue.description' -q '{ issue(id:"FLOW-1") { description } }'
#                                                        # print `jq -r FILTER` of the body
#
# Requires: LINEAR_API_KEY (personal API key, or a full header value such as
# "Bearer <oauth-token>"), curl, jq.
# Exit status: 0 when the response has no `errors` array, 1 otherwise.
# Without -r, always prints the body; callers MUST inspect `errors` before
# trusting `data`. With -r, a response carrying `errors` prints the body to
# stderr instead of applying FILTER, so Markdown fields (description, body,
# content) can be printed raw without hiding failures behind `null`.

set -euo pipefail

if [ -z "${LINEAR_API_KEY:-}" ]; then
  echo "LINEAR_API_KEY is not set" >&2
  exit 2
fi

query=""
variables="{}"
show_headers=0
raw_filter=""

while [ $# -gt 0 ]; do
  case "$1" in
    -q) query="$2"; shift 2 ;;
    -v) variables="$2"; shift 2 ;;
    -H) show_headers=1; shift ;;
    -r) raw_filter="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$query" ]; then
  if [ -t 0 ]; then
    echo "no query: pass -q or pipe a document on stdin" >&2
    exit 2
  fi
  query="$(cat)"
fi

payload="$(jq -cn --arg q "$query" --argjson v "$variables" '{query: $q, variables: $v}')"

if [ "$show_headers" = 1 ]; then
  response="$(curl -sS -D /dev/stderr -X POST https://api.linear.app/graphql \
    -H "Content-Type: application/json" \
    -H "Authorization: $LINEAR_API_KEY" \
    --data-binary "$payload")"
else
  response="$(curl -sS -X POST https://api.linear.app/graphql \
    -H "Content-Type: application/json" \
    -H "Authorization: $LINEAR_API_KEY" \
    --data-binary "$payload")"
fi

if printf '%s' "$response" | jq -e 'has("errors")' >/dev/null 2>&1; then
  if [ -n "$raw_filter" ]; then
    printf '%s' "$response" | jq . >&2
  else
    printf '%s' "$response" | jq .
  fi
  exit 1
fi

if [ -n "$raw_filter" ]; then
  printf '%s' "$response" | jq -r "$raw_filter"
else
  printf '%s' "$response" | jq .
fi
