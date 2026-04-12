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
# API server
uvicorn api_server.main:app --host 0.0.0.0 --port 8000

# Price watcher (background)
python -m price_watcher.main &

# Dispatcher (background)
python -m dispatcher.main &

# Frontend
cd frontend && npm run dev
```

## Environment Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_URL` | `redis://localhost:6379` | Redis connection |
| `K8S_MODE` | `dry-run` | `dry-run` (dev) or `live` (prod) |
| `AUTH_ENABLED` | `false` | Cognito JWT auth |
| `DISPATCH_MODE` | `rule` | `rule` or `agent` |
| `SPOT_REGIONS` | `us-east-1,us-east-2,us-west-2` | Target regions |
| `PRICE_POLL_INTERVAL` | `60` | Price polling seconds |

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
| K8s API timeout | Ensure `K8S_MODE=dry-run` |
| Frontend build fails | `rm -rf node_modules && npm install` |
| Docker buildx missing | `docker buildx create --name amd64builder --use` |
