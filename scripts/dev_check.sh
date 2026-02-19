#!/usr/bin/env bash
# Start the dev server under nix develop, run checks, and print results.
# This script is intended to be executed via: nix develop . --command ./scripts/dev_check.sh

set -uo pipefail

echo "Stopping any running quickheadlines processes (pkill may be missing)"
if command -v pkill >/dev/null 2>&1; then
  pkill -f quickheadlines || true
else
  echo "pkill not found; skipping pkill"
fi

echo "Starting server (background) and redirecting logs to /tmp/server.out"
env APP_ENV=development crystal run src/quickheadlines.cr -- config=feeds.yml > /tmp/server.out 2>&1 &
SERVER_PID=$!
echo "server pid: $SERVER_PID"
sleep 4

echo "--- grep normalization lines ---"
grep -nE "Normaliz|Normalize|normalized|Normalized" /tmp/server.out || true

echo "--- tail /tmp/server.out (last 200 lines) ---"
tail -n 200 /tmp/server.out || true

echo "--- fetch /api/timeline (limit=200) ---"
curl -s "http://localhost:8080/api/timeline?limit=200&offset=0" -o /tmp/timeline.json || true

echo "--- order check ---"
python3 - <<'PY'
import json
import sys
try:
    it=json.load(open('/tmp/timeline.json')).get('items',[])
except Exception as e:
    print('failed to load /tmp/timeline.json:', e); sys.exit(0)
prev=None
ok=True
for i,x in enumerate(it[:200]):
    pd=x.get('pub_date') or ''
    print(f"{i:03d}\t{pd}\t{id(x.get('id'))}")
    if prev is not None and pd>prev:
        ok=False
    prev=pd
print('sorted_desc:',ok)
PY

echo "--- pagination fetch (limit=35) ---"
curl -s "http://localhost:8080/api/timeline?limit=35&offset=0" -o /tmp/t0.json || true
curl -s "http://localhost:8080/api/timeline?limit=35&offset=35" -o /tmp/t1.json || true
python3 - <<'PY2'
import json
import sys
try:
    a=json.load(open('/tmp/t0.json'))['items']
    b=json.load(open('/tmp/t1.json'))['items']
    print('t0 len', len(a), 't1 len', len(b))
    print('t0 last:', a[-1].get('pub_date') if a else None, 'id:', a[-1].get('id') if a else None)
    print('t1 first:', b[0].get('pub_date') if b else None, 'id:', b[0].get('id') if b else None)
except Exception as e:
    print('pagination check failed:', e)
PY2

echo "Done. Server pid: $SERVER_PID"
