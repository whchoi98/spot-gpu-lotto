# Module Reference

## src/api_server — FastAPI REST API

### Role
FastAPI application serving the REST API. Handles job submission, status queries, price data, admin operations, SSE streaming, and AI agent chat.
Auth: Cognito JWT in prod, hardcoded `dev-user/admin` when `AUTH_ENABLED=false`.

### Endpoints
- `POST /api/jobs` — Submit GPU job to Redis queue (no job_id returned; dispatcher generates it)
- `GET /api/jobs/{job_id}` — Get job status from Redis hash
- `DELETE /api/jobs/{job_id}` — Cancel a running job
- `GET /api/jobs/{job_id}/stream` — SSE stream for real-time status updates
- `PUT /api/settings/webhook` — Save user webhook URL
- `GET /api/prices` — Current spot prices (from Redis sorted set)
- `POST /api/upload/presign` — Generate S3 presigned upload URL
- `GET /api/templates` — List job templates
- `POST /api/templates` — Create/save a template
- `DELETE /api/templates/{name}` — Delete a template
- `GET /api/admin/jobs` — List all active jobs (admin only)
- `DELETE /api/admin/jobs/{job_id}` — Force-delete a job
- `POST /api/admin/jobs/{job_id}/retry` — Retry a failed job
- `GET /api/admin/regions` — List regions with capacity
- `PUT /api/admin/regions/{region}/capacity` — Update region capacity
- `GET /api/admin/stats` — Active job count + queue depth
- `POST /api/agent/chat` — AI chat (Bedrock Converse + Redis context, hybrid approval)
- `GET /api/me` — Current user info
- `GET /healthz` — Liveness probe
- `GET /readyz` — Readiness probe (checks Redis)
- `GET /metrics` — Prometheus metrics export

### Key Files
- `main.py` — FastAPI app, CORS, router registration, `/api/me`, `/metrics`
- `auth.py` — JWT validation, `get_current_user` / `require_admin` dependencies
- `routes/jobs.py` — Job CRUD + SSE streaming
- `routes/prices.py` — Price query endpoints
- `routes/admin.py` — Admin-only endpoints
- `routes/agent.py` — AI agent chat (Bedrock Converse + Redis context)
- `routes/templates.py` — Job template CRUD
- `routes/upload.py` — S3 presigned URL generation
- `routes/health.py` — Liveness and readiness probes

---

## src/common — Shared Utilities

### Role
Shared utilities, models, configuration, and client factories used by all services.

### Key Files
- `config.py` — `Settings` class via pydantic-settings (env vars), cached with `@lru_cache`
- `models.py` — Pydantic models: `JobRequest`, `JobRecord`, `JobStatus` enum
- `redis_client.py` — Async Redis connection factory (singleton)
- `k8s_client.py` — Kubernetes client factory per region (uses `aws eks get-token`)
- `logging.py` — structlog JSON logger setup
- `metrics.py` — Prometheus counters/gauges (JOBS_DISPATCHED, QUEUE_DEPTH, etc.)

### Redis Key Structure
- `gpu:spot:prices` — Sorted set: `{region}:{instance_type}` scored by price
- `gpu:job:queue` — List: job payloads (BRPOP by dispatcher)
- `gpu:jobs:{job_id}` — Hash: job record fields
- `gpu:active_jobs` — Set: currently active job IDs
- `gpu:jobs:{job_id}:status` — Pub/Sub channel for SSE streaming
- `gpu:user:{user_id}:webhook` — String: user's webhook URL

---

## src/dispatcher — Job Queue Processor

### Role
Consumes jobs from Redis queue (BRPOP loop), selects the cheapest region, creates GPU Pods via Kubernetes API, and records job state in Redis.

### Key Files
- `main.py` — Entry point, starts queue processor and reaper
- `queue_processor.py` — `process_queue()` BRPOP loop + `process_one_job()` dispatch logic
- `region_selector.py` — `select_region()` reads sorted set, iterates cheapest-first
- `capacity.py` — Atomic GPU capacity management with Redis transactions
- `pod_builder.py` — `build_gpu_pod()` constructs V1Pod with volume mounts (FSx/S3)
- `reaper.py` — Job reaper: handles retry, timeout, and cancel for stale/failed jobs
- `notifier.py` — `notify_job_status()` publishes to Redis Pub/Sub + webhook

### Job Lifecycle
1. BRPOP from `gpu:job:queue`
2. `select_region()` finds cheapest region with capacity
3. If no capacity: retry up to `max_retries`, then fail
4. `build_gpu_pod()` with mounts: /data/models (RO), /data/results (RW), /data/checkpoints
5. In `live` mode: `k8s.create_namespaced_pod()`; in `dry-run`: log only
6. Record job in `gpu:jobs:{job_id}` hash + add to `gpu:active_jobs` set
7. Notify via Pub/Sub + webhook

---

## src/price_watcher — Spot Price Collector

### Role
Periodically polls EC2 Spot price API across configured regions and stores prices in Redis sorted set.

### Key Files
- `main.py` — Entry point, polling loop, Redis write
- `collector.py` — `collect_prices()` calls EC2 `describe_spot_price_history()`

### Notes
- Poll interval: `POLL_INTERVAL` env var (default 30s dev)
- Price mode: `live` (real EC2 API) or `mock` (static test data)
- Sorted set: ZADD with GT flag (atomic replace)

---

## src/agent — Strands AI Agent

### Role
Strands-based AI agent deployed on AgentCore Runtime (us-east-1). Natural-language interface for GPU job scheduling and AWS infrastructure management.

### Key Files
- `app.py` — BedrockAgentCoreApp entrypoint, assembles job + infra tools
- `tools_jobs.py` — Job management @tool functions (httpx → API Server)
- `tools_infra.py` — Infrastructure management @tool functions (boto3 → AWS APIs)
- `system_prompt.py` — Agent system prompt with job + infra guidelines

### Job Tools (httpx → API Server)
get_prices, submit_job, get_job_status, cancel_job, list_jobs, get_stats

### Infra Tools (boto3/kubernetes → AWS APIs)
list_clusters, list_nodes, list_pods, describe_nodepool, get_helm_status, describe_redis, get_cost_summary

---

## src/tests — Test Suite

### Structure
- `conftest.py` — Shared fixtures (fakeredis async client, test settings)
- `unit/` — Unit tests (fast, no external dependencies, fakeredis)
- `integration/` — Integration tests (testcontainers[redis])

### Unit Tests
test_auth, test_capacity, test_collector, test_config, test_models, test_notifier, test_pod_builder, test_reaper, test_region_selector, test_agent_config, test_queue_processor, test_tools_jobs, test_tools_infra

### Integration Tests
test_api_admin, test_api_health, test_api_jobs, test_api_prices, test_api_templates

---

## frontend — React SPA

### Role
React SPA dashboard. Job management, price monitoring, admin panel, AI chat, usage guide. Bilingual (Korean/English).

### Key Directories
- `src/pages/` — Route pages (Dashboard, Jobs, JobNew, JobDetail, Prices, Guide, Agent, Settings, Templates)
- `src/components/ui/` — shadcn/ui primitives (do not modify directly)
- `src/components/jobs/` — Job-specific components
- `src/components/layout/` — Sidebar, Header, ThemeToggle
- `src/hooks/` — TanStack Query hooks (useJobs, usePrices, useAdmin, useJobStream, useAuth, useTemplates) + useTheme
- `src/lib/` — API client, types, i18n, utils

### Notes
- Agent.tsx uses react-markdown + remark-gfm for chat rendering
- Docker: use `Dockerfile.prod` for cross-platform builds

---

## helm/gpu-lotto — Helm 3 Chart

### Role
Helm chart for deploying GPU Spot Lotto to EKS. Manages api-server, dispatcher, price-watcher, frontend, and monitoring.

### Key Files
- `Chart.yaml` — Chart metadata (name: gpu-lotto)
- `values.yaml` — Default values
- `values-dev.yaml` — Dev overrides (dry-run, single replicas, auth disabled)
- `values-prod.yaml` — Prod overrides (live mode, HPA, auth enabled)
- `templates/configmap.yaml` — Shared ConfigMap
- `templates/networkpolicy.yaml` — Network isolation rules
- `templates/targetgroupbinding.yaml` — TargetGroupBinding CRDs (auto-sync Pod IPs to ALB)
- `templates/monitoring/` — ServiceMonitor for Prometheus

### Notes
- ConfigMap changes require `kubectl rollout restart`
- ALB target registration is automatic via TargetGroupBinding + AWS LB Controller
- TargetGroupBinding uses `elbv2.k8s.aws/v1beta1` API

---

## terraform — Infrastructure as Code

### Role
13 Terraform modules covering networking, compute, storage, auth, and observability.

### Modules
vpc, eks, karpenter, elasticache, cognito, alb, cloudfront, ecr, fsx, s3, pod_identity, github_oidc, monitoring

### Environments
- `envs/dev/` — Dev (Seoul, ap-northeast-2)
- `envs/prod/` — Prod

### Notes
- State stored in S3 backend with DynamoDB locking
- All modules use variable inputs — no hardcoded values

---

## k8s — Kubernetes Manifests

### Role
Karpenter NodePool and storage PersistentVolumes. Applied directly (not via Helm) as cluster-level resources.

### Key Files
- `karpenter-gpu-spot.yaml` — Karpenter NodePool for GPU Spot instances (g5, g6, g6e)
- `fsx-lustre-pv.yaml` — FSx Lustre PV/PVC template (envsubst variables)
- `s3-mountpoint-pv.yaml` — S3 Mountpoint CSI PV/PVC (fallback storage mode)

### Notes
- PVs are per-region — must be created in each spot region's EKS cluster
- `envsubst < fsx-lustre-pv.yaml | kubectl apply -f -` (requires `FSX_FILESYSTEM_ID`, `FSX_DNS_NAME`, `FSX_MOUNT_NAME`)

---

## demos — Interactive Demo Scripts

### Role
Interactive bash demo scripts showcasing GPU Spot Lotto features.

### Scripts
- `launcher.sh` — Interactive menu to select and run any demo
- `scenario1-cost-optimized.sh` — Spot price scan, job submit, auto-dispatch, cost analysis
- `scenario2-spot-recovery.sh` — Checkpoint, training, spot interruption, auto-recovery
- `scenario3-full-lifecycle.sh` — Architecture, S3 upload, price scan, FSx import, training, export
- `scenario4-ai-agent.sh` — Agent price query, failure analysis, smart dispatch
- `watch-gpu-pods.sh` — Real-time multi-region GPU pod monitor

### Notes
- ASCII-only characters (no Unicode)
- `GPU_LOTTO_URL` env var overrides default CloudFront URL
- `AGENTCORE_CMD` env var overrides default `.venv/bin/agentcore` for scenario4
