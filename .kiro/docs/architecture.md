# Architecture

## System Overview
```
User -> CloudFront -> ALB -> API Server -> Redis (prices + queue + jobs)
                                              |
                             Dispatcher (BRPOP -> cheapest region -> EKS Pod)
                             Price Watcher (60s -> EC2 Spot API -> Redis)

User (NL) -> AgentCore Runtime -> Strands Agent -> API (tools)
External Agent -> AgentCore Gateway (MCP) -> API Server
```

## Hub-and-Spoke Storage
```
              Seoul S3 Hub (models, datasets, checkpoints, results)
                  /              |              \
        FSx Lustre          FSx Lustre        FSx Lustre
       (us-east-1)         (us-east-2)       (us-west-2)
```

## Components

### API Server (FastAPI)
- 18 REST endpoints: jobs, prices, admin, templates, upload, health, metrics
- Cognito JWT auth (prod) / disabled (dev)
- SSE streaming for real-time job status
- Prometheus `/metrics` endpoint

### Dispatcher
- BRPOP loop consuming from Redis job queue
- Region selector: cheapest-first with capacity check
- Pod builder: GPU Pod with FSx/S3 volume mounts
- Reaper: handles retry, timeout, cancel for stale jobs
- Notifier: Redis Pub/Sub + webhook

### Price Watcher
- Polls EC2 `describe_spot_price_history()` every 60s
- Stores in Redis sorted set (score = price)
- Supports `live` (real API) and `mock` (static data) modes

### AI Agent
- Strands SDK on AgentCore Runtime
- Tools: check_spot_prices, submit_gpu_job, get_job_status, list_active_jobs, get_failure_history
- AgentCore Gateway exposes REST API as MCP tools

### Frontend
- React 18 SPA with shadcn/ui
- Pages: Dashboard, Jobs, Prices, Admin, Guide
- Bilingual: Korean/English (react-i18next)

## Infrastructure
- Control plane: Seoul (ap-northeast-2) — EKS, ElastiCache Redis, ALB, CloudFront
- Spot regions: us-east-1, us-east-2, us-west-2 — EKS with Karpenter GPU Spot nodes
- Storage: Seoul S3 hub + FSx Lustre per spot region (auto-import/export)
- IaC: Terraform (13 modules) + Helm 3 chart
