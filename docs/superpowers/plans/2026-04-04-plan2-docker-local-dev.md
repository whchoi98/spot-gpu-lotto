# GPU Spot Lotto — Plan 2: Docker & Local Dev

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Containerize the 3 Python backend services and create a docker-compose environment for local development and E2E testing with mock/dry-run modes.

**Architecture:** Each microservice gets a multi-stage Dockerfile (build → slim runtime). A shared docker-compose.yml brings up Redis + all 3 services with local-dev env vars (AUTH_ENABLED=false, K8S_MODE=dry-run, PRICE_MODE=mock). A smoke test script validates the full stack.

**Tech Stack:** Docker, docker-compose, Python 3.11-slim, Redis 7 Alpine

**Spec:** `docs/superpowers/specs/2026-04-03-gpu-spot-lotto-design.md` (section 13.3)

**Depends on:** Plan 1 (Python Backend) — all `src/` code is implemented.

---

## File Map

### Create

```
Dockerfile                       # Shared multi-stage Dockerfile for all 3 services
docker-compose.yml               # Local dev: Redis + api-server + dispatcher + price-watcher
docker-compose.test.yml          # Override: run pytest inside container
.dockerignore                    # Exclude .venv, __pycache__, .git, etc.
scripts/smoke-test.sh            # E2E smoke test: submit job, check status, check prices
```

### Modify

```
.gitignore                       # Add Docker-related ignores
```

---

## Task 1: .dockerignore

**Files:**
- Create: `.dockerignore`

- [ ] **Step 1: Create .dockerignore**

```
.venv/
__pycache__/
*.pyc
*.egg-info/
dist/
.pytest_cache/
.mypy_cache/
.ruff_cache/
.git/
.github/
docs/
k8s/
terraform/
frontend/
*.md
!README.md
```

- [ ] **Step 2: Commit**

```bash
git add .dockerignore
git commit -m "chore: add .dockerignore"
```

---

## Task 2: Shared Dockerfile

**Files:**
- Create: `Dockerfile`

- [ ] **Step 1: Create Dockerfile**

A single multi-stage Dockerfile that builds all 3 services. The `target` build arg or `--target` flag selects which entrypoint to use.

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.11-slim AS base

WORKDIR /app

# Install dependencies only (cached layer)
COPY pyproject.toml .
RUN pip install --no-cache-dir . && rm -rf /root/.cache/pip

# Copy source code
COPY src/ src/

# --- API Server ---
FROM base AS api-server
EXPOSE 8000
CMD ["uvicorn", "api_server.main:app", "--host", "0.0.0.0", "--port", "8000"]
ENV PYTHONPATH=/app/src

# --- Dispatcher ---
FROM base AS dispatcher
CMD ["python", "-m", "dispatcher.main"]
ENV PYTHONPATH=/app/src

# --- Price Watcher ---
FROM base AS price-watcher
CMD ["python", "-m", "price_watcher.main"]
ENV PYTHONPATH=/app/src
```

- [ ] **Step 2: Verify Dockerfile syntax**

Run: `docker build --target api-server -t gpu-lotto-api:test . 2>&1 | tail -5`
Expected: Successfully built / tagged

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat: add multi-stage Dockerfile for all 3 services"
```

---

## Task 3: docker-compose.yml

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Create docker-compose.yml**

```yaml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  api-server:
    build:
      context: .
      target: api-server
    ports:
      - "8000:8000"
    environment:
      REDIS_URL: redis://redis:6379
      AUTH_ENABLED: "false"
      K8S_MODE: "dry-run"
    depends_on:
      redis:
        condition: service_healthy

  dispatcher:
    build:
      context: .
      target: dispatcher
    environment:
      REDIS_URL: redis://redis:6379
      K8S_MODE: "dry-run"
    depends_on:
      redis:
        condition: service_healthy

  price-watcher:
    build:
      context: .
      target: price-watcher
    environment:
      REDIS_URL: redis://redis:6379
      PRICE_MODE: "mock"
      POLL_INTERVAL: "10"
    depends_on:
      redis:
        condition: service_healthy
```

- [ ] **Step 2: Build and start the stack**

Run: `docker compose up --build -d`
Expected: 4 containers running (redis, api-server, dispatcher, price-watcher)

- [ ] **Step 3: Verify services are healthy**

Run: `docker compose ps`
Expected: All services "Up"

Run: `curl -s http://localhost:8000/healthz | python -m json.tool`
Expected: `{"status": "ok"}`

Run: `curl -s http://localhost:8000/readyz | python -m json.tool`
Expected: `{"status": "ok", "redis": "connected"}`

- [ ] **Step 4: Stop the stack**

Run: `docker compose down`

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add docker-compose.yml for local dev environment"
```

---

## Task 4: Smoke test script

**Files:**
- Create: `scripts/smoke-test.sh`

- [ ] **Step 1: Create scripts directory and smoke test**

```bash
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
        ((PASS++))
    else
        echo "  FAIL: $desc (got: $result)"
        ((FAIL++))
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
check "metrics endpoint" "$metrics" "gpu_lotto_jobs_submitted_total"

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/smoke-test.sh`

- [ ] **Step 3: Run the smoke test**

Run: `docker compose up --build -d && sleep 5 && ./scripts/smoke-test.sh`
Expected: All checks PASS

- [ ] **Step 4: Cleanup**

Run: `docker compose down`

- [ ] **Step 5: Commit**

```bash
git add scripts/smoke-test.sh
git commit -m "feat: add E2E smoke test script for docker-compose stack"
```

---

## Task 5: docker-compose.test.yml

**Files:**
- Create: `docker-compose.test.yml`

- [ ] **Step 1: Create test compose override**

```yaml
# docker-compose.test.yml — Run pytest inside a container with real Redis
services:
  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  test-runner:
    build:
      context: .
      target: base
    command: >
      sh -c "pip install --no-cache-dir '.[dev]' && pytest src/tests/ -v"
    environment:
      REDIS_URL: redis://redis:6379
      PYTHONPATH: /app/src
    depends_on:
      redis:
        condition: service_healthy
```

NOTE: This reuses the `base` stage from the shared Dockerfile. The `base` stage has the runtime deps; the test override installs dev deps on top and runs pytest.

- [ ] **Step 2: Run containerized tests**

Run: `docker compose -f docker-compose.test.yml run --rm test-runner`
Expected: All 69 tests pass

- [ ] **Step 3: Cleanup**

Run: `docker compose -f docker-compose.test.yml down`

- [ ] **Step 4: Commit**

```bash
git add docker-compose.test.yml
git commit -m "feat: add docker-compose.test.yml for containerized test execution"
```

---

## Task 6: Update .gitignore

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Update .gitignore with Docker entries**

Add these lines to the existing `.gitignore`:

```
# Docker
docker-compose.override.yml
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add Docker entries to .gitignore"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Dockerfile for api-server, dispatcher, price-watcher — Task 2
- [x] docker-compose.yml with Redis + 3 services — Task 3
- [x] AUTH_ENABLED=false, K8S_MODE=dry-run, PRICE_MODE=mock — Task 3
- [x] Health check verification — Task 3, Task 4
- [x] E2E smoke test — Task 4
- [x] Containerized test execution — Task 5
- [x] .dockerignore — Task 1

**Placeholder scan:** No TBD/TODO. All tasks have complete code.

**Type consistency:** Docker service names (`api-server`, `dispatcher`, `price-watcher`) match spec naming. Build targets match Dockerfile stages. Environment variables match Settings class fields in `src/common/config.py`.
