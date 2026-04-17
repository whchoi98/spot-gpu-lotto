# Development Setup

## Prerequisites
- Python 3.11+
- Node.js 18+ and npm
- Docker with buildx support
- AWS CLI v2 (configured credentials)
- kubectl (connected to EKS)
- Helm 3
- Terraform 1.x
- Redis 7 (or use fakeredis for tests)

## Backend
```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

# Verify
ruff check src/
mypy src/
pytest -v
```

## Frontend
```bash
cd frontend
npm install
npm run dev          # http://localhost:5173
npx tsc --noEmit     # type check
```

## Run Locally
```bash
# API server (includes /api/agent/chat endpoint)
uvicorn api_server.main:app --host 0.0.0.0 --port 8000

# Price watcher (background)
python -m price_watcher.main &

# Dispatcher (background)
python -m dispatcher.main &

# Frontend
cd frontend && npm run dev
```

## Agent Development
```bash
# Local dev (hot reload)
agentcore dev

# Deploy to AgentCore Runtime (us-east-1)
agentcore deploy

# Test invoke
agentcore invoke '{"prompt": "Show me current spot prices"}'
```

## Environment Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_URL` | `redis://localhost:6379` | Redis connection |
| `K8S_MODE` | `dry-run` | `dry-run` (dev) or `live` (prod) |
| `AUTH_ENABLED` | `false` | Cognito JWT auth |
| `DISPATCH_MODE` | `rule` | `rule` or `agent` |
| `AGENT_MODEL` | `global.anthropic.claude-sonnet-4-6` | LLM model |
| `SPOT_REGIONS` | `us-east-1,us-east-2,us-west-2` | Target regions |
| `CLUSTER_PREFIX` | `gpu-lotto-dev` | EKS cluster name prefix |
| `API_SERVER_URL` | CloudFront URL | API base URL for agent tools |
| `PRICE_POLL_INTERVAL` | `60` | Price polling seconds |
| `S3_BUCKET` | — | Seoul S3 hub bucket name |

## Docker Build
```bash
# Backend (from project root, --target for multi-stage)
docker buildx build --builder amd64builder --platform linux/arm64 --target <service> \
  -t 660619595884.dkr.ecr.ap-northeast-2.amazonaws.com/gpu-lotto/<service>:<tag> --push .

# Frontend (from frontend/)
docker buildx build --builder amd64builder --platform linux/arm64 \
  -f Dockerfile.prod -t 660619595884.dkr.ecr.ap-northeast-2.amazonaws.com/gpu-lotto/frontend:<tag> --push .
```

## Helm Deploy
```bash
helm upgrade gpu-lotto helm/gpu-lotto -n gpu-lotto -f helm/gpu-lotto/values-dev.yaml
kubectl rollout restart deploy/gpu-lotto-api-server deploy/gpu-lotto-dispatcher -n gpu-lotto
```

## Terraform
```bash
cd terraform/envs/dev
terraform plan
terraform apply
```

## Testing
```bash
pytest src/tests/unit/ -v          # unit (fakeredis, fast)
pytest src/tests/integration/ -v   # integration (testcontainers, needs Docker)
pytest -v                          # all
```

## Troubleshooting
| Issue | Fix |
|-------|-----|
| Redis connection error | Set `REDIS_URL=redis://localhost:6379` |
| K8s API timeout | Ensure `K8S_MODE=dry-run` for local dev |
| Frontend build fails | `rm -rf node_modules && npm install` |
| Docker buildx missing | `docker buildx create --name amd64builder --use` |
| Agent chat 502 | Check `AGENT_MODEL` and Bedrock access in us-east-1 |
| ALB target unhealthy | Pod IP changed — wait for TargetGroupBinding re-sync |
| FSx PV apply fails | Run `envsubst` with required vars before `kubectl apply` |
