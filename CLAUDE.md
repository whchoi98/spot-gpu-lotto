# Project Context

## Overview
GPU Spot Lotto -- Multi-region GPU Spot instance price monitoring and workload dispatch system.
Seoul (ap-northeast-2) control plane orchestrates Spot GPU jobs across us-east-1, us-east-2, us-west-2.
Hub-and-Spoke data architecture: Seoul S3 Hub + FSx Lustre auto-sync per spot region.

## Tech Stack

### Backend (Python 3.11)
- FastAPI + Uvicorn (async API server)
- Redis (sorted sets for prices, lists for queue, hashes for jobs)
- boto3/aioboto3 (EC2 Spot price API, S3 presigned URLs)
- kubernetes (Pod creation in remote EKS clusters)
- Pydantic v2 + pydantic-settings (validation, config)
- structlog (structured JSON logging)
- prometheus-client (metrics export)
- sse-starlette (real-time job status streaming)

### Frontend (TypeScript)
- React 18 + Vite
- shadcn/ui (Radix primitives + Tailwind CSS)
- TanStack Query (server state management)
- react-i18next (ko/en bilingual)
- Lucide React (icons)
- react-router-dom v6 (routing)
- axios (HTTP client)
- i18next (internationalization)
- react-markdown + remark-gfm (Agent chat markdown rendering)

### AI Agent
- Strands Agents SDK (tool-use agent framework)
- Amazon Bedrock AgentCore Runtime (serverless agent deployment)
- Amazon Bedrock Converse API (web chat streaming via API Server)

### Infrastructure
- Helm 3 chart (gpu-lotto)
- Terraform (VPC, EKS, ElastiCache Redis, IAM)
- Karpenter (GPU Spot node provisioning)
- FSx Lustre (auto-import/export to S3)
- ALB + CloudFront (HTTPS frontend + API routing)
- Grafana + Prometheus (monitoring)

### Testing
- pytest + pytest-asyncio (backend)
- fakeredis (Redis mock for unit tests)
- testcontainers[redis] (integration tests)
- ruff (linting), mypy (type checking)

## Project Structure
```
src/
  api_server/     - FastAPI routes, auth, middleware
  common/         - Shared models, config, Redis/K8s clients, metrics
  dispatcher/     - Job queue processor, pod builder, region selector, notifier
  price_watcher/  - Spot price collector (EC2 API polling)
  agent/          - Strands AI agent on AgentCore Runtime (natural-language job dispatch)
  tests/          - Unit and integration tests (pytest)
frontend/         - React SPA (Vite + shadcn/ui)
helm/gpu-lotto/   - Helm chart (templates, values-dev/prod)
terraform/        - IaC modules (VPC, EKS, ElastiCache, IAM, etc. -- 13 modules)
k8s/              - Karpenter NodePool, FSx/S3 PV manifests
demos/            - Interactive demo scripts (scenario 1-4)
scripts/          - Utility scripts
tools/            - Scripts and prompts
docs/             - Architecture, ADRs, runbooks, specs/plans
```

## Conventions
- Python: ruff (E, F, I, N, W rules), line-length=100, target py311
- Python: mypy strict mode
- Python: async-first (all Redis/HTTP operations are async)
- TypeScript: strict mode, path alias `@/` -> `src/`
- Git commits: conventional commits (`feat:`, `fix:`, `docs:`, etc.)
- Config: environment variables via pydantic-settings (REDIS_URL, K8S_MODE, etc.)
- k8s_mode: "live" in dev and prod (real GPU clusters)
- dispatch_mode: "rule" (default) or "agent" (AI-based dispatch via Strands agent)
- agent_model: LLM model for agent (default: `global.anthropic.claude-sonnet-4-6`)
- Images: cross-compile with `docker buildx --platform linux/amd64` (dev host is ARM Graviton)
- ECR tags: immutable -- increment version on each push (v9, v10, ...)
- ALB: IP target type -- must re-register Pod IP after restart

## Key Commands

### Backend
```bash
# Run API server
uvicorn api_server.main:app --host 0.0.0.0 --port 8000

# Run tests
pytest -v
pytest src/tests/unit/ -v          # unit only
pytest src/tests/integration/ -v   # integration only

# Lint & type check
ruff check src/
mypy src/
```

### Frontend
```bash
cd frontend
npm run dev          # dev server (Vite)
npm run build        # production build
npx tsc --noEmit     # type check only
```

### Agent (AgentCore Runtime)
```bash
# Local dev (hot reload)
agentcore dev

# Deploy to AgentCore Runtime
agentcore deploy

# Invoke deployed agent
agentcore invoke --payload '{"prompt": "Find the cheapest p4d.24xlarge spot instance"}'
```

### Docker & Deploy
```bash
# Build backend (from project root)
docker buildx build --builder amd64builder --platform linux/amd64 \
  -t 660619595884.dkr.ecr.ap-northeast-2.amazonaws.com/gpu-lotto/<service>:<tag> --push .

# Build frontend (from frontend/)
docker buildx build --builder amd64builder --platform linux/amd64 \
  -f Dockerfile.prod -t 660619595884.dkr.ecr.ap-northeast-2.amazonaws.com/gpu-lotto/frontend:<tag> --push .

# Helm deploy
helm upgrade gpu-lotto helm/gpu-lotto -n gpu-lotto -f helm/gpu-lotto/values-dev.yaml

# Restart pods (after ConfigMap change)
kubectl rollout restart deploy/gpu-lotto-api-server deploy/gpu-lotto-dispatcher -n gpu-lotto
```

### Terraform
```bash
cd terraform/envs/dev
terraform plan
terraform apply
```

---

## Auto-Sync Rules

Rules below are applied automatically after Plan mode exit and on major code changes.

### Post-Plan Mode Actions
After exiting Plan mode (`/plan`), before starting implementation:

1. **Architecture decision made** -> Update `ARCHITECTURE.md`
2. **Technical choice/trade-off made** -> Create `docs/decisions/ADR-NNN-title.md`
3. **New module added** -> Create `CLAUDE.md` in that module directory
4. **Operational procedure defined** -> Create runbook in `docs/runbooks/`
5. **Changes needed in this file** -> Update relevant sections above

### Code Change Sync Rules
- New directory under `src/` -> Must create `CLAUDE.md` alongside
- API endpoint added/changed -> Update `src/api_server/CLAUDE.md`
- Redis key structure changed -> Update `src/common/CLAUDE.md`
- Dispatcher logic changed -> Update `src/dispatcher/CLAUDE.md`
- Helm chart changed -> Update `helm/gpu-lotto/CLAUDE.md`
- Infrastructure changed -> Update `ARCHITECTURE.md` Infrastructure section

### ADR Numbering
Find the highest number in `docs/decisions/ADR-*.md` and increment by 1.
Format: `ADR-NNN-concise-title.md`
