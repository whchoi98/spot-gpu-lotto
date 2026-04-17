# Architecture

## System Overview
```
User -> CloudFront -> ALB -> API Server -> Redis (prices + queue + jobs)
                                |              |
                     /api/agent/chat     Dispatcher (BRPOP -> cheapest region -> EKS Pod)
                     (Bedrock Converse    Price Watcher (60s -> EC2 Spot API -> Redis)
                      + Redis context)

User (NL) -> AgentCore Runtime (us-east-1) -> Strands Agent -> API Server (httpx)
                                                            -> AWS APIs (boto3/k8s)
```

## Hub-and-Spoke Storage
```
              Seoul S3 Hub (models, datasets, checkpoints, results)
                  /              |              \
        FSx Lustre          FSx Lustre        FSx Lustre
       (us-east-1)         (us-east-2)       (us-west-2)
     auto-import/export   auto-import/export  auto-import/export
```

FSx PV manifests use `envsubst` for per-region filesystem IDs.

## Components

### API Server (FastAPI)
- 20 REST endpoints: jobs, prices, admin, templates, upload, agent/chat, health, metrics
- `POST /api/agent/chat`: Bedrock Converse with Redis context injection, hybrid approval model
- Cognito JWT auth (prod) / disabled (dev, hardcoded `dev-user/admin`)
- SSE streaming for real-time job status (`/api/jobs/{job_id}/stream`)
- Prometheus `/metrics` endpoint
- Pydantic model validation runs BEFORE FastAPI dependency injection (auth)

### Dual Agent Architecture (ADR-002)

**Chat Endpoint** (`routes/agent.py`):
- Bedrock Converse API, single-turn
- Injects real-time Redis data (prices, stats, capacity) into system prompt
- Hybrid approval: LLM proposes actions via `proposal` code blocks, user approves in UI
- Runs inside API server — direct Redis access

**Strands Agent** (`src/agent/`):
- Full tool-use agent on AgentCore Runtime (us-east-1)
- `tools_jobs.py`: httpx → API Server (no direct Redis — solves VPC access issue)
- `tools_infra.py`: boto3/kubernetes → AWS APIs directly (EKS, ElastiCache, Cost Explorer)
- Model: `global.anthropic.claude-sonnet-4-6` (cross-region inference via `global.*` prefix)

### Dispatcher
- BRPOP loop consuming from Redis job queue
- Region selector: cheapest-first with capacity check (atomic Redis transactions)
- Pod builder: GPU Pod with FSx/S3 volume mounts, `nodeSelector: gpu-lotto/pool: gpu-spot`
- Reaper: handles retry, timeout, cancel for stale jobs
- `job_id` generated here (UUID4), NOT by API server
- Supports two storage modes: "fsx" (FSx Lustre PVCs) and "s3" (emptyDir fallback)

### Price Watcher
- Polls EC2 `describe_spot_price_history()` every 60s (configurable via `POLL_INTERVAL`)
- Stores in Redis sorted set (ZADD with GT flag, score = price)
- Supports `live` (real API) and `mock` (static data) modes

### Frontend
- React 18 SPA with shadcn/ui
- Pages: Dashboard, Jobs, Prices, Admin, Agent (chat UI), Guide, Settings, Templates
- Agent page: markdown rendering (react-markdown + remark-gfm), action approval buttons
- Bilingual: Korean/English (react-i18next)
- API calls via `src/lib/api.ts` (axios, base: `/api`)

### Monitoring
- Prometheus ServiceMonitor for API server metrics
- Grafana dashboard ConfigMap (auto-provisioned via Helm)

## Infrastructure
- Control plane: Seoul (ap-northeast-2) — EKS, ElastiCache Redis (TLS), ALB, CloudFront
- Spot regions: us-east-1, us-east-2, us-west-2 — EKS with Karpenter GPU Spot nodes
- AgentCore Runtime: us-east-1 (cross-region inference via `global.*` model prefix)
- Storage: Seoul S3 hub + FSx Lustre per spot region (auto-import/export)
- EKS cluster naming: `{cluster_prefix}-{region_short}` (e.g. `gpu-lotto-dev-seoul`, `gpu-lotto-dev-use1`)
- IaC: Terraform (13 modules) + Helm 3 chart
- ALB: IP target type, Pod IPs auto-synced via TargetGroupBinding + AWS LB Controller (Pod Identity)
- ECR: immutable tags, increment version on each push

## ADRs
- ADR-001: AgentCore + Strands AI Agent
- ADR-002: Hybrid Agent Chat Architecture (Bedrock Converse + Strands)
