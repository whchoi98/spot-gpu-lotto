#!/usr/bin/env bash
# scripts/smoke-test.sh — E2E smoke test for docker-compose stack
set -euo pipefail

API="http://localhost:8000"
PASS=0
FAIL=0

check() {
    local desc="$1"
    local result="$2"
    local expected="$3"
    if echo "$result" | grep -q "$expected"; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (got: $result)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== GPU Spot Lotto Smoke Test ==="
echo ""

# 1. Health check
echo "[1] Health checks"
check "healthz" "$(curl -sf $API/healthz)" '"status":"ok"'
check "readyz"  "$(curl -sf $API/readyz)"  '"redis":"connected"'

# 2. Wait for price watcher to populate prices (mock mode, 10s interval)
echo ""
echo "[2] Waiting for mock prices (up to 15s)..."
for i in $(seq 1 15); do
    prices=$(curl -sf "$API/api/prices" || echo '{"prices":[]}')
    count=$(echo "$prices" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['prices']))" 2>/dev/null || echo 0)
    if [ "$count" -gt 0 ]; then
        break
    fi
    sleep 1
done
check "prices populated" "$count" "[1-9]"

# 3. Get prices with filter
echo ""
echo "[3] Price filtering"
filtered=$(curl -sf "$API/api/prices?instance_type=g6.xlarge")
fcount=$(echo "$filtered" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['prices']))" 2>/dev/null || echo 0)
check "filtered prices (g6.xlarge)" "$fcount" "[1-9]"

# 4. Submit a job
echo ""
echo "[4] Job submission"
submit=$(curl -sf -X POST "$API/api/jobs" \
    -H "Content-Type: application/json" \
    -d '{"user_id":"smoke-test","image":"nvidia/cuda:12.0-base","instance_type":"g6.xlarge"}')
check "job submitted" "$submit" '"status":"queued"'

# 5. Templates CRUD
echo ""
echo "[5] Templates"
save=$(curl -sf -X POST "$API/api/templates" \
    -H "Content-Type: application/json" \
    -d '{"name":"Smoke Test","image":"test:v1","instance_type":"g6.xlarge","gpu_count":1,"storage_mode":"s3","command":["echo","hi"]}')
check "template saved" "$save" '"status":"saved"'

list=$(curl -sf "$API/api/templates")
check "template listed" "$list" '"Smoke Test"'

del=$(curl -sf -X DELETE "$API/api/templates/Smoke%20Test")
check "template deleted" "$del" '"status":"deleted"'

# 6. Admin endpoints
echo ""
echo "[6] Admin"
stats=$(curl -sf "$API/api/admin/stats")
check "admin stats" "$stats" '"queue_depth"'

regions=$(curl -sf "$API/api/admin/regions")
check "admin regions" "$regions" '"regions"'

# 7. Metrics
echo ""
echo "[7] Prometheus metrics"
metrics=$(curl -sf "$API/metrics")
check "metrics endpoint" "$metrics" "process_virtual_memory_bytes"

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
