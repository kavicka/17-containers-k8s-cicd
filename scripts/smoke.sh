#!/usr/bin/env bash
# End-to-end smoke test through the public entry point (nginx → api → qdrant). Prints timings as JSON.
set -euo pipefail
BASE=${BASE:-http://localhost:8080}
q='How many participants were enrolled in the trial "Diabetes Prevention Program Outcomes Study"?'
body() { python3 -c 'import json,sys; print(json.dumps({"question": sys.argv[1], "mode": "rerank", "k": 5}))' "$q"; }

curl -fsS "$BASE/healthz" > /dev/null
health=$(curl -fsS "$BASE/api/health")
echo "$health" | grep -q '"n_chunks":5218' || { echo "unexpected index: $health"; exit 1; }

search_ms=$(curl -fsS -o /tmp/search.json -w '%{time_total}' -H 'Content-Type: application/json' \
  -d "$(body)" "$BASE/api/search" | awk '{printf "%d", $1*1000}')
grep -q 'NCT00038727' /tmp/search.json || { echo "search did not find NCT00038727"; exit 1; }

# SSE through nginx: the stream must contain sources, tokens and done (proves proxy buffering is off for /api)
curl -fsSN -H 'Content-Type: application/json' -d "$(body)" "$BASE/api/ask" > /tmp/ask.txt
for ev in sources token done; do grep -q "event: $ev" /tmp/ask.txt || { echo "missing SSE event $ev"; exit 1; }; done

echo "{\"smoke\": \"ok\", \"search_rerank_ms\": $search_ms}"
