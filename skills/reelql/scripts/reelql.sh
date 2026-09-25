#!/usr/bin/env bash
# Analyze video URLs with ReelQL: bash reelql.sh URL [URL...]
# Saves each result as reelql-<n>.json in the current directory (n = the URL's position) and prints one status line per URL.
# Needs REELQL_API_KEY; runs two at a time, the per-key limit. Never prints the key.
set -u
API=${REELQL_API:-https://reelql.tail6c0e2d.ts.net}
[ -n "${REELQL_API_KEY:-}" ] || { echo "REELQL_API_KEY is not set. Get a key by DMing @tomcupr on X (https://x.com/tomcupr), then: export REELQL_API_KEY=<your key>"; exit 2; }
H="X-API-Key: $REELQL_API_KEY"

run() {  # $1 url, $2 output file
  r=$(curl -s "$API/jobs" -H "$H" -H 'Content-Type: application/json' -d "$(jq -n --arg u "$1" '{url: $u}')")
  id=$(jq -r '.id // empty' <<<"$r")
  [ -n "$id" ] || { echo "refused  $1: $(jq -r '.detail // .' <<<"$r")"; return; }
  while :; do
    curl -s "$API/jobs/$id" -H "$H" > "$2"; s=$(jq -r .status "$2")
    [ "$s" = queued ] || [ "$s" = running ] || break
    sleep 5
  done
  echo "$s $2  $1 $(jq -r '.error // empty | tostring' "$2")"
}

i=0
for u in "$@"; do
  i=$((i + 1)); run "$u" "reelql-$i.json" &
  [ $((i % 2)) = 0 ] && wait
done
wait
