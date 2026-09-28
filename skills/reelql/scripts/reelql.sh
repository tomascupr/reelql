#!/usr/bin/env bash
# Analyze video URLs with ReelQL: bash reelql.sh URL [URL...]
# A payment link for more credit: bash reelql.sh --topup DOLLARS (5 to 500)
# Saves each result as reelql-<n>.json in the current directory (n = the URL's position) and prints one status line per URL.
# Needs REELQL_API_KEY; runs two at a time, the per-key limit. Never prints the key.
set -u
API=${REELQL_API:-https://reelql.tail6c0e2d.ts.net}
[ -n "${REELQL_API_KEY:-}" ] || { echo "REELQL_API_KEY is not set. Get a free key (10 minutes of video) with: curl -s -X POST $API/keys  then: export REELQL_API_KEY=<the key>"; exit 2; }
H="X-API-Key: $REELQL_API_KEY"

if [ "${1:-}" = --topup ]; then
  body=$(jq -n --argjson u "${2:-}" '{usd: $u}' 2>/dev/null) || { echo "usage: reelql.sh --topup DOLLARS (5 to 500)"; exit 2; }
  curl -s "$API/credits/checkout" -H "$H" -H 'Content-Type: application/json' -d "$body" |
    jq -r 'if .url then "Pay here to add \(.minutes) minutes of video: \(.url)" else "refused: \(.detail | tostring)" end'
  curl -s "$API/balance" -H "$H" | jq -r '"Credit left: \(.minutes // "unlimited") minutes"'
  exit
fi

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
