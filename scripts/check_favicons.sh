#!/usr/bin/env bash
# Simple CI-friendly favicon route checker
set -euo pipefail

HOST=${1:-http://127.0.0.1}
PORTS=(3030 8080)
PORT=""

for p in "${PORTS[@]}"; do
  if curl -sS -m3 -o /dev/null -w "%{http_code}" "${HOST}:$p/api/feeds" | grep -q "200"; then
    PORT=$p
    break
  fi
done

if [ -z "$PORT" ]; then
  echo "Server not responding on ${HOST}:3030 or ${HOST}:8080" >&2
  exit 2
fi

echo "Using ${HOST}:$PORT"

TMP=/tmp/qh_favlist.txt
grep -o '/favicons/[^\"]*' /tmp/feeds.json 2>/dev/null || true
if ! curl -sS "${HOST}:$PORT/api/feeds" -o /tmp/feeds.json; then
  echo "Failed to fetch /api/feeds" >&2
  exit 3
fi

grep -o '/favicons/[^\"]*' /tmp/feeds.json | sort | uniq | head -n10 > "$TMP"

failed=0
while IFS= read -r path; do
  echo "Checking $path"
  headers=$(curl -I -s "${HOST}:$PORT${path}") || true
  echo "$headers"
  echo "----"
  # simple checks
  if ! echo "$headers" | grep -qi "200 OK"; then
    echo "ERROR: $path did not return 200" >&2
    failed=$((failed+1))
    continue
  fi
  if ! echo "$headers" | grep -qi "Access-Control-Allow-Origin: \*"; then
    echo "ERROR: $path missing Access-Control-Allow-Origin: *" >&2
    failed=$((failed+1))
  fi
done < "$TMP"

if [ "$failed" -ne 0 ]; then
  echo "One or more favicon checks failed" >&2
  exit 4
fi

echo "All favicon checks passed"
exit 0
