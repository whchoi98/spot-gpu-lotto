# Developer Onboarding

## Quick Start

### 1. Prerequisites
- [ ] Python 3.11+ installed
- [ ] Node.js 20+ installed
- [ ] AWS CLI v2 configured (`aws sts get-caller-identity`)
- [ ] Docker with buildx (`docker buildx version`)
- [ ] kubectl configured for EKS clusters
- [ ] Helm 3 installed
- [ ] Repository access granted (whchoi98/spot-gpu-lotto)
- [ ] Environment variables configured (see `.env.example`)

### 2. Backend Setup
```bash
git clone https://github.com/whchoi98/spot-gpu-lotto.git
cd spot-gpu-lotto

# Python virtual environment
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"

# Verify
ruff check src/
mypy src/
pytest -v
```

### 3. Frontend Setup
```bash
cd frontend
npm install
npm run dev          # dev server at http://localhost:5173
npx tsc --noEmit     # type check
```

### 4. Verify
```bash
# Backend API server (separate terminal)
uvicorn api_server.main:app --host 0.0.0.0 --port 8000

# Frontend dev server
cd frontend && npm run dev
```

## Project Overview
- Read `CLAUDE.md` for project context, tech stack, and conventions
- Read `ARCHITECTURE.md` for system design
- Review `docs/decisions/` for architectural decisions (ADRs)

## Development Workflow
- Branch naming: `feat/`, `fix/`, `docs/`, `refactor/`
- Commit convention: Conventional Commits (`feat:`, `fix:`, `docs:`, etc.)
- Lint before commit: `ruff check src/` and `npx tsc --noEmit`
- K8s mode: `dry-run` in dev (no real GPU clusters)

## Key Concepts
- **Hub-and-Spoke**: Seoul (ap-northeast-2) control plane + US Spot regions
- **Price Watcher**: Polls EC2 Spot prices → Redis sorted set
- **Dispatcher**: BRPOP queue → cheapest region → K8s Pod
- **Agent**: Strands SDK on AgentCore Runtime (natural language dispatch)

## Troubleshooting

| Issue | Solution |
|-------|---------|
| Redis connection error | Set `REDIS_URL=redis://localhost:6379` or use `fakeredis` in tests |
| K8s API timeout | Ensure `K8S_MODE=dry-run` for local dev |
| Frontend build fails | `cd frontend && rm -rf node_modules && npm install` |
| Docker buildx not found | `docker buildx create --name amd64builder --use` |

## Resources
- Architecture: `ARCHITECTURE.md`
- ADRs: `docs/decisions/`
- Runbooks: `docs/runbooks/`
- Helm chart: `helm/gpu-lotto/`
- Terraform: `terraform/envs/dev/`
