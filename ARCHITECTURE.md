# GPU Spot Lotto -- Architecture

> Multi-region GPU Spot price monitoring and workload dispatch system.
> Seoul (ap-northeast-2) control plane orchestrates GPU jobs across us-east-1, us-east-2, us-west-2.
> Hub-and-Spoke data architecture: Seoul S3 hub + FSx Lustre auto-sync per spot region.

---

## 1. System Architecture

```
                     ap-northeast-2 (Seoul, Control Plane)
  ┌──────────────────────────────────────────────────────────────────┐
  │                                                                  │
  │  CloudFront ──▶ ALB ──▶ API Server (FastAPI)                     │
  │   + WAF           │       ├── /api/jobs      (submit, status)    │
  │                   │       ├── /api/prices    (spot prices)       │
  │                   │       ├── /api/admin     (manage, stats)     │
  │                   │       ├── /api/templates (saved configs)     │
  │                   │       ├── /api/upload    (S3 presign)        │
  │                   │       ├── /api/agent     (AI chat)           │
  │                   │       └── /metrics       (Prometheus)        │
  │                   │                 │                             │
  │                   │           Redis (ElastiCache)                 │
  │                   │       ┌─────┴──────┐                         │
  │                   │   Sorted Set     List (Queue)                │
  │                   │   (prices)         │                         │
  │                   │       │        Dispatcher ──▶ K8s Pod        │
  │                   │       │            │                         │
  │                   │   Price Watcher    Reaper (cleanup)          │
  │                   │   (EC2 API poll)   Notifier (webhook+pubsub) │
  │                   │                                              │
  │  Frontend ◀───────┘       S3 Hub Bucket                          │
  │  (React SPA)          (models/datasets/checkpoints/results)      │
  │                                                                  │
  │  AgentCore Runtime (ap-northeast-2, serverless)                  │
  │    └── Strands AI Agent                                          │
  │          ├── Job Tools (httpx) ──▶ API Server ──▶ Redis          │
  │          └── Infra Tools (boto3/k8s) ──▶ AWS APIs                │
  │                                                                  │
  └─────────────────────┬────────────────────────────────────────────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
  │  us-east-1  │ │  us-east-2  │ │  us-west-2  │
  │  EKS Auto   │ │  EKS Auto   │ │  EKS Auto   │
  │  Karpenter  │ │  Karpenter  │ │  Karpenter  │
  │  GPU Spot   │ │  GPU Spot   │ │  GPU Spot   │
  │      │      │ │      │      │ │      │      │
  │ FSx Lustre  │ │ FSx Lustre  │ │ FSx Lustre  │
  │ (S3 cache)  │ │ (S3 cache)  │ │ (S3 cache)  │
  └─────────────┘ └─────────────┘ └─────────────┘
```

---

## 2. Components

### 2.1 Backend Services

| Component | Source | Role |
|-----------|--------|------|
| API Server | `src/api_server/` | FastAPI -- 20 endpoints: jobs, prices, admin, templates, upload, agent chat, health, metrics |
| Dispatcher | `src/dispatcher/` | BRPOP queue consumer, cheapest-region selector, K8s Pod creator, job reaper |
| Price Watcher | `src/price_watcher/` | EC2 Spot price collector (60s polling) -> Redis Sorted Set |
| AI Agent | `src/agent/` | Strands SDK agent on AgentCore Runtime -- natural-language job + infra management |
| Common | `src/common/` | Shared config, models, Redis/K8s clients, metrics, logging |

### 2.2 Frontend

| Component | Source | Role |
|-----------|--------|------|
| React SPA | `frontend/` | Dashboard, job management, price monitoring, AI agent chat, admin panel, guide |
| Pages | `frontend/src/pages/` | Dashboard, Jobs, JobNew, JobDetail, Prices, Templates, Agent, Guide, Settings, Admin (AdminDashboard, AdminJobs, AdminRegions) |
| Hooks | `frontend/src/hooks/` | TanStack Query hooks: useJobs, usePrices, useAdmin, useJobStream, useTheme |
| i18n | `frontend/src/lib/i18n.ts` | Bilingual (Korean/English) translations |

### 2.3 Infrastructure

| Component | Source | Role |
|-----------|--------|------|
| Helm Chart | `helm/gpu-lotto/` | K8s deployment: 18 templates for api-server, dispatcher, price-watcher, frontend, monitoring |
| Terraform | `terraform/` | 13 IaC modules: VPC, EKS, Karpenter, ElastiCache, Cognito, ALB, CloudFront, ECR, FSx, S3, Pod Identity, GitHub OIDC, Monitoring |
| K8s Manifests | `k8s/` | Karpenter NodePool, FSx Lustre PV, S3 Mountpoint PV |
| AgentCore | `.bedrock_agentcore.yaml` | Agent runtime config (Python 3.11, linux/arm64) |
| Demos | `demos/` | 4 interactive bash demo scripts with animated terminal UI |

---

## 3. Data Flow

### 3.1 Rule-Based Dispatch (dispatch_mode: rule)

```
User ──▶ POST /api/jobs ──▶ LPUSH gpu:job:queue
                                    │
Dispatcher ◀── BRPOP ──────────────┘
    │
    ├── ZRANGE gpu:spot:prices 0 -1  (cheapest region)
    ├── DECR gpu:capacity:{region}   (atomic slot)
    ├── K8s API: create Pod          (target region EKS)
    ├── HSET gpu:jobs:{id}           (record state)
    └── PUBLISH + webhook            (notify user)
                                          │
Reaper (10s loop) ──▶ check Pod status ──┘
    │
    ├── Succeeded: delete Pod, INCR capacity, update status
    ├── Failed: retry (up to max_retries) or mark failed
    └── Cancelled: force-delete Pod, return capacity
```

### 3.2 AI Agent Dispatch (dispatch_mode: agent)

Two tool categories, single agent:

```
User (natural language) ──▶ AgentCore Runtime (Strands Agent)
    │
    ├── Job Tools (httpx → API Server → Redis)
    │    ├── get_prices          -> GET /api/prices
    │    ├── submit_job          -> POST /api/jobs
    │    ├── get_job_status      -> GET /api/jobs/{id}
    │    ├── cancel_job          -> DELETE /api/jobs/{id}
    │    ├── list_jobs           -> GET /api/admin/jobs
    │    └── get_stats           -> GET /api/admin/stats
    │
    └── Infra Tools (boto3/kubernetes → AWS APIs)
         ├── list_clusters       -> boto3 eks (all 4 regions)
         ├── list_nodes          -> kubernetes API (node details)
         ├── list_pods           -> kubernetes API (pod status)
         ├── describe_nodepool   -> kubernetes CRD (Karpenter)
         ├── get_helm_status     -> helm CLI (release status)
         ├── describe_redis      -> boto3 elasticache
         └── get_cost_summary    -> boto3 cost explorer
```

Job tools use httpx to call API Server endpoints — no duplicate Redis logic.
Infra tools use boto3/kubernetes for direct AWS API access with AgentCore execution role.

---

## 4. Redis Data Structure

```
gpu:spot:prices                  Sorted Set   {region}:{instance_type} -> price (auto-sorted)
gpu:job:queue                    List          job payloads (BRPOP by dispatcher)
gpu:jobs:{job_id}                Hash          job record (status, region, pod_name, ...)
gpu:active_jobs                  Set           currently active job IDs
gpu:jobs:{job_id}:status         Pub/Sub       SSE streaming channel
gpu:capacity:{region}            String        available GPU slot counter (atomic DECR/INCR)
gpu:user:{user_id}:webhook       String        user's webhook URL
```

---

## 5. Cross-Region Storage

### 5.1 Hub-and-Spoke Architecture

```
         Seoul S3 Hub (ap-northeast-2)
         models/ | datasets/ | checkpoints/ | results/
              /          |          \
     AutoImport     AutoImport     AutoImport
     AutoExport     AutoExport     AutoExport
          |              |              |
    FSx Lustre     FSx Lustre     FSx Lustre
    (us-east-1)    (us-east-2)    (us-west-2)
         |              |              |
      GPU Pod        GPU Pod        GPU Pod
    /data/models   /data/models   /data/models    (RO, FSx PVC)
    /data/results  /data/results  /data/results   (RW, FSx PVC)
    /data/checkpoints  ...         ...             (RW, emptyDir -- NOT persisted to S3)
```

### 5.2 Storage Modes

| Mode | Mechanism | Performance | Cost | Best For |
|------|-----------|-------------|------|----------|
| `fsx` | FSx Lustre + S3 auto-sync | Local SSD cache, very fast | ~$140/TB/month | Repeated reads, large training, checkpointing |
| `s3` | S3 Mountpoint CSI | Cross-region S3 direct | S3 request fees only | Short inference, one-time model loading |

Selected per job via `storage_mode` parameter at submission time.

---

## 6. EKS & Karpenter

### 6.1 Cluster Config

| Setting | Value |
|---------|-------|
| Mode | EKS Auto Mode (Karpenter built-in) |
| K8s Version | 1.35 |
| Node AMI | Bottlerocket Accelerated (GPU drivers pre-installed) |
| Namespace | `gpu-jobs` (GPU workloads) |

### 6.2 Karpenter NodePool

```yaml
requirements:
  - karpenter.sh/capacity-type: ["spot"]          # Spot only
  - karpenter.k8s.aws/instance-category: ["g"]    # GPU instances
  - karpenter.k8s.aws/instance-generation: > "4"  # g5, g6, g6e
  - karpenter.k8s.aws/instance-size: ["xlarge", "2xlarge"]
taints:
  - nvidia.com/gpu: NoSchedule                    # GPU workloads only
consolidation: 30s idle -> scale down
expiration: 2h max lifetime
limits: 16 GPUs total
```

### 6.3 Spot Interruption Handling

| Layer | Response |
|-------|----------|
| Karpenter | Auto-provisions replacement Spot node |
| EKS Auto Mode | Node Monitoring Agent detects GPU failure, recovers within 10 min |
| Application | Periodic checkpoints to `/data/checkpoints/` |
| Dispatcher | Detects Pod failure, retries in alternate region |

---

## 7. Terraform Infrastructure (13 Modules)

| Module | Key Resources |
|--------|---------------|
| `vpc` | VPC, 3 AZ public/private subnets, NAT Gateway |
| `eks` | EKS cluster (Auto Mode), IAM roles, security groups |
| `karpenter` | NodePool (GPU Spot), EC2NodeClass (Bottlerocket) |
| `elasticache` | Redis 7 with TLS, multi-AZ, auto-failover |
| `cognito` | User Pool, App Client, OAuth config |
| `alb` | ALB (internet-facing), target groups (IP mode), listener rules |
| `cloudfront` | CloudFront distribution + WAF, caching policies |
| `ecr` | 4 repositories (immutable tags) |
| `fsx` | FSx Lustre per spot region, S3 auto-import/export |
| `s3` | Hub bucket (versioning, encryption, lifecycle) |
| `pod_identity` | EKS Pod Identity / IRSA roles |
| `github_oidc` | GitHub Actions OIDC for CI/CD |
| `monitoring` | Prometheus + Grafana stack |

Environments: `envs/dev/` (Seoul), `envs/prod/`

State: S3 backend with DynamoDB locking.

---

## 8. Helm Chart (gpu-lotto)

### 8.1 Templates (18 files)

| Service | Resources |
|---------|-----------|
| api-server | Deployment (2 replicas), Service, ServiceAccount, HPA (2-6, 70% CPU), Ingress (ALB) |
| dispatcher | Deployment (1 replica), Service, ServiceAccount, PDB (minAvailable: 0) |
| price-watcher | Deployment (1 replica), Service, ServiceAccount |
| frontend | Deployment (2 replicas), Service, ServiceAccount |
| monitoring | ServiceMonitor (Prometheus), Grafana Dashboard ConfigMap |
| shared | ConfigMap (env vars), NetworkPolicy (ingress/egress isolation) |

### 8.2 Values

| File | Mode | Auth | Replicas | Prices |
|------|------|------|----------|--------|
| `values-dev.yaml` | live | disabled | 1 each | live EC2 API |
| `values-prod.yaml` | live | Cognito | HPA | live EC2 API |

---

## 9. AI Agent Architecture

### 9.1 Strands Agent

```
AgentCore Runtime (ap-northeast-2, serverless, Python 3.11, arm64)
    │
    └── Strands Agent
         ├── Model: global.anthropic.claude-sonnet-4-6
         ├── System Prompt: Job + Infra guidelines, VRAM mapping
         │
         ├── Job Tools (httpx → API Server)
         │    ├── get_prices(instance_type, region)
         │    ├── submit_job(instance_type, image, command, ...)
         │    ├── get_job_status(job_id)
         │    ├── cancel_job(job_id)
         │    ├── list_jobs()
         │    └── get_stats()
         │
         └── Infra Tools (boto3/kubernetes → AWS APIs)
              ├── list_clusters()
              ├── list_nodes(region)
              ├── list_pods(region, namespace)
              ├── describe_nodepool(region)
              ├── get_helm_status()
              ├── describe_redis()
              └── get_cost_summary(days)
```

Two tool categories, single agent:
- Job tools call API Server via httpx (single data path, no duplicate Redis logic)
- Infra tools access AWS APIs directly via boto3/kubernetes with AgentCore execution role

### 9.2 API Server Agent Chat (Hybrid)

For web frontend chat, the API Server uses Bedrock Converse API directly (not AgentCore Runtime):

- Endpoint: `POST /api/agent/chat`
- Injects Redis context (prices, capacity, active jobs) into each request
- Hybrid approval model: `submit_job` requires user confirmation, read-only tools auto-approved
- See [ADR-002](docs/decisions/ADR-002-hybrid-agent-chat-architecture.md)

### 9.3 Deployment

```bash
agentcore dev      # Local development with hot reload
agentcore deploy   # Deploy to AgentCore Runtime
agentcore invoke   # Invoke deployed agent
```

Config: `.bedrock_agentcore.yaml`
Dependencies: `requirements.txt` (project root -- AgentCore CLI auto-detects)

---

## 10. Authentication & Security

| Layer | Mechanism |
|-------|-----------|
| Frontend -> API | Cognito JWT (prod) or hardcoded dev-user (dev) |
| API auth | ALB injects `x-amzn-oidc-data` header; `auth.py` validates JWT |
| Admin endpoints | `require_admin` dependency checks role claim |
| K8s access | Pod Identity (IRSA) for S3/EKS API access |
| Redis | ElastiCache with TLS + VPC-only access |
| CI/CD | GitHub OIDC -> ECR push (no stored credentials) |
| WAF | CloudFront WAF rules |
| Network | NetworkPolicy isolates service-to-service traffic |

---

## 11. Observability

| Signal | Tool | Detail |
|--------|------|--------|
| Metrics | Prometheus | API Server `/metrics`, Dispatcher `:9090/metrics` |
| Dashboards | Grafana | ConfigMap-provisioned dashboard (jobs, queue depth, prices) |
| Scraping | ServiceMonitor | Auto-discovered by Prometheus Operator |
| Logging | structlog | JSON format with ISO timestamps, stack info |
| Metrics | prometheus-client | API: JOBS_SUBMITTED, JOBS_ACTIVE, API_REQUEST_DURATION; Dispatcher: JOBS_DISPATCHED, JOBS_FAILED, JOBS_RETRIED, QUEUE_DEPTH, REGION_CAPACITY, JOB_DURATION; Price: SPOT_PRICE, PRICE_FETCH_ERRORS |

---

## 12. Cost Optimization

| Strategy | Mechanism |
|----------|-----------|
| Multi-region Spot | Always dispatch to cheapest of 3 regions |
| Auto scale-down | Karpenter removes idle nodes after 30s |
| FSx Scratch | Matches Spot workload lifecycle (no persistent cost) |
| S3 Mountpoint | Skip FSx for short jobs (storage cost = 0) |
| Node max lifetime | 2h expiry prevents stale Spot pricing |

---

## 13. API Endpoints

### Jobs (prefix: /api)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/jobs` | Submit GPU job to queue |
| GET | `/api/jobs/{job_id}` | Get job status |
| DELETE | `/api/jobs/{job_id}` | Cancel job |
| GET | `/api/jobs/{job_id}/stream` | SSE real-time status |
| PUT | `/api/settings/webhook` | Save webhook URL |

### Prices
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/prices` | Current spot prices (filterable by instance_type) |

### Upload
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/upload/presign` | S3 presigned upload URL |

### Templates
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/templates` | List templates |
| POST | `/api/templates` | Create template |
| DELETE | `/api/templates/{name}` | Delete template |

### Agent (prefix: /api/agent)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/agent/chat` | AI agent chat (Bedrock Converse + Redis context, hybrid approval) |

### Admin (prefix: /api/admin)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/admin/jobs` | List all active jobs |
| DELETE | `/api/admin/jobs/{job_id}` | Force-delete job |
| POST | `/api/admin/jobs/{job_id}/retry` | Retry failed job |
| GET | `/api/admin/regions` | List regions with capacity |
| PUT | `/api/admin/regions/{region}/capacity` | Update capacity |
| GET | `/api/admin/stats` | Job count + queue depth |

### Health & Metrics
| Method | Path | Description |
|--------|------|-------------|
| GET | `/healthz` | Liveness probe |
| GET | `/readyz` | Readiness probe (checks Redis) |
| GET | `/metrics` | Prometheus metrics |

---

## 14. Demo Scripts

| Script | Steps | Highlights |
|--------|-------|------------|
| `scenario1-cost-optimized.sh` | 5 | Price scan, job submit, auto-dispatch, cost analysis, monitoring |
| `scenario2-spot-recovery.sh` | 6 | Checkpoint, training, spot interruption, recovery, resume, cost |
| `scenario3-full-lifecycle.sh` | 7 | Architecture, REAL S3 upload, price scan + capacity, FSx status + REAL dispatch, training, REAL S3 export verification, cost summary + cleanup |
| `scenario4-ai-agent.sh` | 6 | Architecture comparison, agent price query, failure analysis, smart dispatch (hybrid approval), tool architecture, summary |

All scripts: ASCII-only (no Unicode), real API calls, animated terminal UI, `GPU_LOTTO_URL` env var override.

---

## 15. Key Design Decisions

| Decision | Reference |
|----------|-----------|
| Strands + AgentCore for AI agent | [ADR-001](docs/decisions/ADR-001-agentcore-strands-ai-agent.md) |
| Hybrid agent chat (Bedrock Converse in API Server) | [ADR-002](docs/decisions/ADR-002-hybrid-agent-chat-architecture.md) |
| Redis as unified data store (prices + queue + state) | Sorted Set for prices, List for queue, Hash for jobs |
| Hub-and-Spoke storage (Seoul S3 + regional FSx) | Cross-region data access with local caching |
| Karpenter over Cluster Autoscaler | GPU-specific Spot scheduling with fine-grained instance selection |
| EKS Auto Mode | Simplified node management with built-in Karpenter |
| Dual dispatch mode (rule / agent) | Runtime switchable via `DISPATCH_MODE` env var |
