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
- Cognito JWT auth (prod) / disabled (dev)
- SSE streaming for real-time job status
- Prometheus `/metrics` endpoint

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
### Dispatcher
- BRPOP loop consuming from Redis job queue
- Region selector: cheapest-first with capacity check
- Pod builder: GPU Pod with FSx/S3 volume mounts
- Reaper: handles retry, timeout, cancel for stale jobs

### Price Watcher
- Polls EC2 `describe_spot_price_history()` every 60s
- Stores in Redis sorted set (score = price)

### Frontend
- React 18 SPA with shadcn/ui
- Pages: Dashboard, Jobs, Prices, Admin, Agent (chat UI), Guide
- Agent page: markdown rendering (react-markdown + remark-gfm), action approval buttons
- Bilingual: Korean/English (react-i18next)

### Monitoring
- Prometheus ServiceMonitor for API server metrics
- Grafana dashboard ConfigMap (auto-provisioned via Helm)

## Infrastructure
- Control plane: Seoul (ap-northeast-2) — EKS, ElastiCache Redis, ALB, CloudFront
- Spot regions: us-east-1, us-east-2, us-west-2 — EKS with Karpenter GPU Spot nodes
- AgentCore Runtime: us-east-1 (cross-region inference via `global.*` model prefix)
- Storage: Seoul S3 hub + FSx Lustre per spot region (auto-import/export)
- EKS cluster naming: `{cluster_prefix}-{region_short}` (e.g. `gpu-lotto-dev-seoul`, `gpu-lotto-dev-use1`)
- IaC: Terraform (13 modules) + Helm 3 chart

## ADRs
- ADR-001: AgentCore + Strands AI Agent
- ADR-002: Hybrid Agent Chat Architecture (Bedrock Converse + Strands)
