<p align="center">
  <strong>GPU Spot Lotto</strong><br/>
  Multi-Region GPU Spot Price Monitoring &amp; Workload Dispatch System
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License" /></a>
  <img src="https://img.shields.io/badge/python-3.11-blue.svg" alt="Python" />
  <img src="https://img.shields.io/badge/react-18-61DAFB.svg" alt="React" />
  <img src="https://img.shields.io/badge/terraform-1.x-7B42BC.svg" alt="Terraform" />
  <img src="https://img.shields.io/badge/helm-3-0F1689.svg" alt="Helm" />
  <a href="#english"><img src="https://img.shields.io/badge/lang-en-red.svg" alt="English" /></a>
  <a href="#한국어"><img src="https://img.shields.io/badge/lang-ko-yellow.svg" alt="Korean" /></a>
</p>

---

# English

## Overview

GPU Spot Lotto is a system that monitors GPU Spot instance prices across multiple AWS regions in real time and dispatches workloads to the cheapest available region. The Seoul (ap-northeast-2) control plane orchestrates GPU jobs across three US spot regions (us-east-1, us-east-2, us-west-2) using a Hub-and-Spoke data architecture with Seoul S3 as the central hub and FSx Lustre for per-region auto-sync.

```
User -> CloudFront -> ALB -> API Server -> Redis (price DB + job queue)
                                               |
                              Dispatcher (dequeue -> cheapest region EKS)
                                               |
                              Price Watcher (60s polling, EC2 Spot Price API)

User (natural language) -> AgentCore Runtime -> Strands AI Agent -> API (via tools)
External Agent -> AgentCore Gateway (MCP) -> API Server
```

### Hub-and-Spoke Storage

```
               Seoul S3 Hub (models, datasets, checkpoints, results)
                  /              |              \
        FSx Lustre          FSx Lustre        FSx Lustre
       (us-east-1)         (us-east-2)       (us-west-2)
     auto-import/export   auto-import/export  auto-import/export
```

## Features

- **Real-Time Price Monitoring** -- Collects GPU Spot prices from 3 US regions every 60 seconds via the EC2 API and stores them in Redis Sorted Sets for instant lookup.
- **Cheapest-Region Dispatch** -- Automatically selects the lowest-cost region and creates GPU Pods via Kubernetes API, with Karpenter provisioning Spot nodes on demand.
- **Hub-and-Spoke Data Sync** -- Seoul S3 hub with FSx Lustre per spot region provides automatic import/export of models, datasets, and checkpoints.
- **Spot Interruption Recovery** -- Detects preempted instances and automatically reschedules jobs to the next cheapest region, preserving checkpoints.
- **Job Lifecycle Management** -- Full CRUD for GPU jobs including submission, status tracking, SSE real-time streaming, cancellation, and retry.
- **Admin Dashboard** -- Web UI for managing jobs, monitoring prices, viewing region capacity, and controlling system settings with bilingual (EN/KO) support.
- **S3 Presigned Upload** -- Direct browser-to-S3 uploads for training data and model files without proxying through the API server.
- **Job Templates** -- Save and reuse common job configurations to avoid repetitive form filling.
- **Prometheus Metrics** -- Built-in `/metrics` endpoint for Grafana dashboards and alerting.
- **AI Agent Dispatch** -- Natural-language GPU job management via Strands Agents SDK on Amazon Bedrock AgentCore Runtime. Analyzes prices, failure history, and user intent for intelligent scheduling.
- **MCP Gateway** -- AgentCore Gateway exposes REST API as MCP Protocol tools, enabling external AI agents to use GPU Spot Lotto as a tool.
- **Interactive Demos** -- Four bash demo scripts that call real API endpoints with animated terminal UI.

## Prerequisites

- Python 3.11+
- Node.js 18+ and npm
- Docker with buildx support
- AWS CLI v2 (configured with appropriate credentials)
- kubectl (connected to EKS clusters)
- Helm 3
- Terraform 1.x
- Redis 7 (or AWS ElastiCache Redis)

## Installation

### Clone the Repository

```bash
git clone https://github.com/<your-org>/gpu-spot-lotto.git
cd gpu-spot-lotto
```

### Backend Setup

```bash
# Create and activate virtual environment
python -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -e .

# Install dev dependencies (testing, linting)
pip install -e ".[dev]"
```

### Frontend Setup

```bash
cd frontend
npm install
cd ..
```

### Infrastructure Setup

```bash
# Initialize Terraform
cd terraform/envs/dev
terraform init
terraform plan
terraform apply

# Deploy Helm chart
helm upgrade --install gpu-lotto helm/gpu-lotto \
  -n gpu-lotto --create-namespace \
  -f helm/gpu-lotto/values-dev.yaml
```

## Usage

### Start Services Locally

```bash
# Start API server
uvicorn api_server.main:app --host 0.0.0.0 --port 8000

# Start price watcher (background)
python -m price_watcher.main &

# Start dispatcher (background)
python -m dispatcher.main &

# Start frontend dev server
cd frontend && npm run dev
```

### Submit a GPU Job

```bash
# Check current spot prices
curl https://<your-cloudfront-url>/api/prices

# Submit a job (dispatched to cheapest region automatically)
curl -X POST https://<your-cloudfront-url>/api/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user1",
    "image": "my-training-image:latest",
    "instance_type": "g6.xlarge",
    "gpu_count": 1
  }'

# List all jobs (admin)
curl https://<your-cloudfront-url>/api/admin/jobs
```

### Run Demo Scripts

```bash
cd demos

# Scenario 1: Cost-optimized dispatch
bash scenario1-cost-optimized.sh

# Scenario 2: Spot interruption recovery
bash scenario2-spot-recovery.sh

# Scenario 3: Full lifecycle (S3 upload -> training -> export)
bash scenario3-full-lifecycle.sh

# Scenario 4: AI Agent dispatch (AgentCore + Strands)
bash scenario4-ai-agent.sh
```

### Docker Build and Deploy

```bash
# Login to ECR
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# Build and push backend (ARM host -> AMD64 target)
docker buildx build --builder amd64builder --platform linux/amd64 \
  -t <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/gpu-lotto/api-server:v10 --push .

# Build and push frontend
cd frontend
npm run build
docker buildx build --builder amd64builder --platform linux/amd64 \
  -f Dockerfile.prod \
  -t <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/gpu-lotto/frontend:v7 --push .

# Deploy with Helm
helm upgrade gpu-lotto helm/gpu-lotto -n gpu-lotto -f helm/gpu-lotto/values-dev.yaml

# Restart pods after ConfigMap changes
kubectl rollout restart deploy/gpu-lotto-api-server deploy/gpu-lotto-dispatcher -n gpu-lotto
```

## Configuration

All configuration is managed through environment variables via `pydantic-settings`.

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` |
| `K8S_MODE` | Kubernetes mode (`dry-run` or `live`) | `dry-run` |
| `AUTH_ENABLED` | Enable Cognito JWT authentication | `false` |
| `COGNITO_USER_POOL_ID` | AWS Cognito User Pool ID | -- |
| `COGNITO_APP_CLIENT_ID` | Cognito App Client ID | -- |
| `AWS_REGION` | Control plane AWS region | `ap-northeast-2` |
| `SPOT_REGIONS` | Comma-separated spot target regions | `us-east-1,us-east-2,us-west-2` |
| `S3_BUCKET` | Hub S3 bucket name | -- |
| `PRICE_POLL_INTERVAL` | Price collection interval (seconds) | `60` |
| `DISPATCH_MODE` | Dispatch strategy (`rule` or `agent`) | `rule` |
| `AGENT_MODEL` | LLM model for AI agent | `global.anthropic.claude-sonnet-4-6` |
| `GPU_LOTTO_URL` | API base URL (for demo scripts) | CloudFront URL |
| `AGENTCORE_CMD` | AgentCore CLI path (for demo scripts) | `.venv/bin/agentcore` |

### Helm Values

- `values-dev.yaml` -- Dev environment: dry-run mode, single replicas, auth disabled
- `values-prod.yaml` -- Prod environment: live mode, HPA enabled, Cognito auth

## Project Structure

```
gpu-spot-lotto/
├── src/
│   ├── api_server/          # FastAPI REST API (18 endpoints)
│   │   ├── main.py          # App entry, CORS, router registration
│   │   ├── auth.py          # JWT validation, role-based access
│   │   └── routes/          # jobs, prices, admin, templates, upload, health
│   ├── common/              # Shared models, config, Redis/K8s clients
│   ├── dispatcher/          # Job queue processor, pod builder, region selector
│   ├── price_watcher/       # EC2 Spot price collector (60s polling)
│   ├── agent/               # Strands AI agent (AgentCore Runtime)
│   └── tests/               # pytest suite (unit + integration)
│       ├── unit/            # 11 test modules (fakeredis, no external deps)
│       └── integration/     # 5 test modules (testcontainers Redis)
├── frontend/                # React 18 + Vite + shadcn/ui SPA
│   ├── src/pages/           # Dashboard, Jobs, Prices, Admin, Guide
│   ├── src/components/      # UI primitives, job components, layout
│   ├── src/hooks/           # TanStack Query hooks
│   └── src/lib/             # API client, types, i18n (ko/en)
├── helm/gpu-lotto/          # Helm 3 chart
│   └── templates/           # api-server, dispatcher, price-watcher, frontend
├── terraform/               # 13 IaC modules
│   ├── modules/             # vpc, eks, karpenter, elasticache, cognito, ...
│   └── envs/                # dev (Seoul), prod
├── k8s/                     # Karpenter NodePool, FSx/S3 PV manifests
├── demos/                   # 4 interactive demo scripts
├── pyproject.toml           # Python project config (deps, pytest, ruff, mypy)
└── CLAUDE.md                # Project context for AI-assisted development
```

## Testing

### Run All Tests

```bash
pytest -v
```

### Unit Tests Only

```bash
pytest src/tests/unit/ -v
```

Unit tests use `fakeredis` for in-memory Redis simulation. No external services required.

### Integration Tests Only

```bash
pytest src/tests/integration/ -v
```

Integration tests use `testcontainers` to spin up a real Redis instance in Docker.

### Linting and Type Checking

```bash
# Lint with ruff
ruff check src/

# Type check with mypy
mypy src/

# Frontend type check
cd frontend && npx tsc --noEmit
```

### Test Coverage

| Category | Modules | Description |
|----------|---------|-------------|
| Unit | auth, capacity, collector, config, models, notifier, pod_builder, reaper, region_selector, agent_config, agent_tools | Core logic tests with fakeredis |
| Integration | api_admin, api_health, api_jobs, api_prices, api_templates | Full API endpoint tests with real Redis |

## API Documentation

### Jobs

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/jobs` | Submit GPU job to queue |
| `GET` | `/api/jobs/{job_id}` | Get job status |
| `DELETE` | `/api/jobs/{job_id}` | Cancel a job |
| `GET` | `/api/jobs/{job_id}/stream` | SSE real-time status stream |
| `PUT` | `/api/settings/webhook` | Save webhook URL |

### Prices

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/prices` | Current spot prices across all regions |

### Upload

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/upload/presign` | Generate S3 presigned upload URL |

### Templates

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/templates` | List job templates |
| `POST` | `/api/templates` | Create a template |
| `DELETE` | `/api/templates/{name}` | Delete a template |

### Admin

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/admin/jobs` | List all active jobs |
| `DELETE` | `/api/admin/jobs/{job_id}` | Force-delete a job |
| `POST` | `/api/admin/jobs/{job_id}/retry` | Retry a failed job |
| `GET` | `/api/admin/regions` | List regions with capacity |
| `PUT` | `/api/admin/regions/{region}/capacity` | Update region capacity |
| `GET` | `/api/admin/stats` | Job count and queue depth |

### Health and Metrics

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/healthz` | Liveness probe |
| `GET` | `/readyz` | Readiness probe (checks Redis) |
| `GET` | `/metrics` | Prometheus metrics |

## Contributing

1. Fork the repository.
2. Create a feature branch from `main`.
3. Follow existing code conventions:
   - Python: `ruff` (E, F, I, N, W rules), line-length 100, async-first
   - TypeScript: strict mode, path alias `@/`
   - Git: conventional commits (`feat:`, `fix:`, `docs:`, etc.)
4. Add tests for new functionality.
5. Run lint and type checks before submitting.
6. Open a Pull Request with a clear description.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

- Maintainer: GPU Spot Lotto Team
- Issues: Use the GitHub Issues tab to report bugs or request features.

---

# 한국어

## 개요

GPU Spot Lotto는 여러 AWS 리전의 GPU Spot 인스턴스 가격을 실시간으로 모니터링하고, 가장 저렴한 리전에 워크로드를 자동 배치하는 시스템입니다. 서울(ap-northeast-2) 컨트롤 플레인이 3개 미국 Spot 리전(us-east-1, us-east-2, us-west-2)의 GPU 작업을 관리하며, 서울 S3를 중앙 허브로 하는 Hub-and-Spoke 데이터 아키텍처를 사용합니다. 각 Spot 리전에는 FSx Lustre가 자동 동기화를 수행합니다.

```
사용자 -> CloudFront -> ALB -> API 서버 -> Redis (가격 DB + 작업 큐)
                                              |
                             디스패처 (큐 소비 -> 최저가 리전 EKS 배치)
                                              |
                             프라이스 워처 (60초 주기, EC2 Spot 가격 API)

사용자 (자연어) -> AgentCore Runtime -> Strands AI 에이전트 -> API (도구 호출)
외부 에이전트 -> AgentCore Gateway (MCP) -> API 서버
```

### Hub-and-Spoke 스토리지

```
              서울 S3 허브 (모델, 데이터셋, 체크포인트, 결과물)
                  /              |              \
        FSx Lustre          FSx Lustre        FSx Lustre
       (us-east-1)         (us-east-2)       (us-west-2)
     자동 가져오기/내보내기  자동 가져오기/내보내기  자동 가져오기/내보내기
```

## 주요 기능

- **실시간 가격 모니터링** -- EC2 API를 통해 3개 미국 리전의 GPU Spot 가격을 60초마다 수집하고, Redis Sorted Set에 저장하여 즉시 조회할 수 있습니다.
- **최저가 리전 자동 배치** -- 가장 저렴한 리전을 자동 선택하여 Kubernetes API로 GPU Pod를 생성하고, Karpenter가 Spot 노드를 온디맨드로 프로비저닝합니다.
- **Hub-and-Spoke 데이터 동기화** -- 서울 S3 허브와 각 Spot 리전의 FSx Lustre가 모델, 데이터셋, 체크포인트를 자동으로 가져오기/내보내기합니다.
- **Spot 인터럽션 복구** -- 선점된 인스턴스를 감지하고, 체크포인트를 보존하면서 차순위 저렴한 리전으로 작업을 자동 재스케줄링합니다.
- **작업 수명주기 관리** -- GPU 작업의 제출, 상태 추적, SSE 실시간 스트리밍, 취소, 재시도를 포함한 전체 CRUD를 지원합니다.
- **관리자 대시보드** -- 작업 관리, 가격 모니터링, 리전 용량 확인, 시스템 설정 제어를 위한 웹 UI를 제공하며, 한국어/영어 이중 언어를 지원합니다.
- **S3 Presigned 업로드** -- API 서버를 거치지 않고 브라우저에서 S3로 학습 데이터와 모델 파일을 직접 업로드할 수 있습니다.
- **작업 템플릿** -- 자주 사용하는 작업 설정을 저장하고 재사용하여 반복적인 폼 입력을 줄일 수 있습니다.
- **Prometheus 메트릭** -- 내장 `/metrics` 엔드포인트를 통해 Grafana 대시보드와 알림을 구성할 수 있습니다.
- **AI 에이전트 배치** -- Amazon Bedrock AgentCore Runtime 위의 Strands Agents SDK를 통한 자연어 GPU 작업 관리. 가격, 장애 이력, 사용자 의도를 분석하여 지능적으로 스케줄링합니다.
- **MCP 게이트웨이** -- AgentCore Gateway가 REST API를 MCP Protocol 도구로 노출하여, 외부 AI 에이전트가 GPU Spot Lotto를 도구로 사용할 수 있습니다.
- **인터랙티브 데모** -- 실제 API 엔드포인트를 호출하는 4개의 bash 데모 스크립트를 제공합니다.

## 사전 요구 사항

- Python 3.11 이상
- Node.js 18 이상 및 npm
- Docker (buildx 지원 필수)
- AWS CLI v2 (적절한 자격 증명 구성 필요)
- kubectl (EKS 클러스터 연결 필요)
- Helm 3
- Terraform 1.x
- Redis 7 (또는 AWS ElastiCache Redis)

## 설치

### 저장소 복제

```bash
git clone https://github.com/<your-org>/gpu-spot-lotto.git
cd gpu-spot-lotto
```

### 백엔드 설정

```bash
# 가상 환경 생성 및 활성화
python -m venv .venv
source .venv/bin/activate

# 의존성 설치
pip install -e .

# 개발용 의존성 설치 (테스트, 린팅)
pip install -e ".[dev]"
```

### 프론트엔드 설정

```bash
cd frontend
npm install
cd ..
```

### 인프라 설정

```bash
# Terraform 초기화
cd terraform/envs/dev
terraform init
terraform plan
terraform apply

# Helm 차트 배포
helm upgrade --install gpu-lotto helm/gpu-lotto \
  -n gpu-lotto --create-namespace \
  -f helm/gpu-lotto/values-dev.yaml
```

## 사용법

### 로컬 서비스 시작

```bash
# API 서버 시작
uvicorn api_server.main:app --host 0.0.0.0 --port 8000

# 프라이스 워처 시작 (백그라운드)
python -m price_watcher.main &

# 디스패처 시작 (백그라운드)
python -m dispatcher.main &

# 프론트엔드 개발 서버 시작
cd frontend && npm run dev
```

### GPU 작업 제출

```bash
# 현재 Spot 가격 조회
curl https://<your-cloudfront-url>/api/prices

# 작업 제출 (최저가 리전으로 자동 배치)
curl -X POST https://<your-cloudfront-url>/api/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user1",
    "image": "my-training-image:latest",
    "instance_type": "g6.xlarge",
    "gpu_count": 1
  }'

# 전체 작업 목록 조회 (관리자)
curl https://<your-cloudfront-url>/api/admin/jobs
```

### 데모 스크립트 실행

```bash
cd demos

# 시나리오 1: 비용 최적화 배치
bash scenario1-cost-optimized.sh

# 시나리오 2: Spot 인터럽션 복구
bash scenario2-spot-recovery.sh

# 시나리오 3: 전체 수명주기 (S3 업로드 -> 학습 -> 내보내기)
bash scenario3-full-lifecycle.sh

# 시나리오 4: AI 에이전트 배치 (AgentCore + Strands)
bash scenario4-ai-agent.sh
```

### Docker 빌드 및 배포

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# 백엔드 빌드 및 푸시 (ARM 호스트 -> AMD64 타겟)
docker buildx build --builder amd64builder --platform linux/amd64 \
  -t <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/gpu-lotto/api-server:v10 --push .

# 프론트엔드 빌드 및 푸시
cd frontend
npm run build
docker buildx build --builder amd64builder --platform linux/amd64 \
  -f Dockerfile.prod \
  -t <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/gpu-lotto/frontend:v7 --push .

# Helm 배포
helm upgrade gpu-lotto helm/gpu-lotto -n gpu-lotto -f helm/gpu-lotto/values-dev.yaml

# ConfigMap 변경 후 Pod 재시작
kubectl rollout restart deploy/gpu-lotto-api-server deploy/gpu-lotto-dispatcher -n gpu-lotto
```

## 설정

모든 설정은 `pydantic-settings`를 통해 환경 변수로 관리합니다.

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `REDIS_URL` | Redis 연결 문자열 | `redis://localhost:6379` |
| `K8S_MODE` | Kubernetes 모드 (`dry-run` 또는 `live`) | `dry-run` |
| `AUTH_ENABLED` | Cognito JWT 인증 활성화 | `false` |
| `COGNITO_USER_POOL_ID` | AWS Cognito User Pool ID | -- |
| `COGNITO_APP_CLIENT_ID` | Cognito App Client ID | -- |
| `AWS_REGION` | 컨트롤 플레인 AWS 리전 | `ap-northeast-2` |
| `SPOT_REGIONS` | Spot 대상 리전 (쉼표 구분) | `us-east-1,us-east-2,us-west-2` |
| `S3_BUCKET` | 허브 S3 버킷 이름 | -- |
| `PRICE_POLL_INTERVAL` | 가격 수집 주기 (초) | `60` |
| `DISPATCH_MODE` | 배치 전략 (`rule` 또는 `agent`) | `rule` |
| `AGENT_MODEL` | AI 에이전트 LLM 모델 | `global.anthropic.claude-sonnet-4-6` |
| `GPU_LOTTO_URL` | API 기본 URL (데모 스크립트용) | CloudFront URL |
| `AGENTCORE_CMD` | AgentCore CLI 경로 (데모 스크립트용) | `.venv/bin/agentcore` |

### Helm Values

- `values-dev.yaml` -- 개발 환경: dry-run 모드, 단일 레플리카, 인증 비활성화
- `values-prod.yaml` -- 운영 환경: live 모드, HPA 활성화, Cognito 인증

## 프로젝트 구조

```
gpu-spot-lotto/
├── src/
│   ├── api_server/          # FastAPI REST API (18개 엔드포인트)
│   │   ├── main.py          # 앱 엔트리, CORS, 라우터 등록
│   │   ├── auth.py          # JWT 검증, 역할 기반 접근 제어
│   │   └── routes/          # jobs, prices, admin, templates, upload, health
│   ├── common/              # 공유 모델, 설정, Redis/K8s 클라이언트
│   ├── dispatcher/          # 작업 큐 프로세서, Pod 빌더, 리전 선택기
│   ├── price_watcher/       # EC2 Spot 가격 수집기 (60초 주기)
│   ├── agent/               # Strands AI 에이전트 (AgentCore Runtime)
│   └── tests/               # pytest 테스트 (단위 + 통합)
│       ├── unit/            # 11개 테스트 모듈 (fakeredis, 외부 의존성 없음)
│       └── integration/     # 5개 테스트 모듈 (testcontainers Redis)
├── frontend/                # React 18 + Vite + shadcn/ui SPA
│   ├── src/pages/           # 대시보드, 작업, 가격, 관리자, 가이드
│   ├── src/components/      # UI 기본 컴포넌트, 작업 컴포넌트, 레이아웃
│   ├── src/hooks/           # TanStack Query 훅
│   └── src/lib/             # API 클라이언트, 타입, i18n (한/영)
├── helm/gpu-lotto/          # Helm 3 차트
│   └── templates/           # api-server, dispatcher, price-watcher, frontend
├── terraform/               # 13개 IaC 모듈
│   ├── modules/             # vpc, eks, karpenter, elasticache, cognito 등
│   └── envs/                # dev (서울), prod
├── k8s/                     # Karpenter NodePool, FSx/S3 PV 매니페스트
├── demos/                   # 4개 인터랙티브 데모 스크립트
├── pyproject.toml           # Python 프로젝트 설정 (의존성, pytest, ruff, mypy)
└── CLAUDE.md                # AI 보조 개발을 위한 프로젝트 컨텍스트
```

## 테스트

### 전체 테스트 실행

```bash
pytest -v
```

### 단위 테스트만 실행

```bash
pytest src/tests/unit/ -v
```

단위 테스트는 인메모리 Redis 시뮬레이션을 위해 `fakeredis`를 사용합니다. 외부 서비스가 필요하지 않습니다.

### 통합 테스트만 실행

```bash
pytest src/tests/integration/ -v
```

통합 테스트는 `testcontainers`를 사용하여 Docker에서 실제 Redis 인스턴스를 실행합니다.

### 린팅 및 타입 검사

```bash
# ruff 린팅
ruff check src/

# mypy 타입 검사
mypy src/

# 프론트엔드 타입 검사
cd frontend && npx tsc --noEmit
```

### 테스트 범위

| 카테고리 | 모듈 | 설명 |
|----------|------|------|
| 단위 | auth, capacity, collector, config, models, notifier, pod_builder, reaper, region_selector, agent_config, agent_tools | fakeredis를 사용한 핵심 로직 테스트 |
| 통합 | api_admin, api_health, api_jobs, api_prices, api_templates | 실제 Redis를 사용한 전체 API 엔드포인트 테스트 |

## API 문서

### 작업 (Jobs)

| 메서드 | 엔드포인트 | 설명 |
|--------|-----------|------|
| `POST` | `/api/jobs` | GPU 작업을 큐에 제출합니다 |
| `GET` | `/api/jobs/{job_id}` | 작업 상태를 조회합니다 |
| `DELETE` | `/api/jobs/{job_id}` | 작업을 취소합니다 |
| `GET` | `/api/jobs/{job_id}/stream` | SSE 실시간 상태 스트림입니다 |
| `PUT` | `/api/settings/webhook` | 웹훅 URL을 저장합니다 |

### 가격 (Prices)

| 메서드 | 엔드포인트 | 설명 |
|--------|-----------|------|
| `GET` | `/api/prices` | 전체 리전의 현재 Spot 가격을 조회합니다 |

### 업로드 (Upload)

| 메서드 | 엔드포인트 | 설명 |
|--------|-----------|------|
| `POST` | `/api/upload/presign` | S3 presigned 업로드 URL을 생성합니다 |

### 템플릿 (Templates)

| 메서드 | 엔드포인트 | 설명 |
|--------|-----------|------|
| `GET` | `/api/templates` | 작업 템플릿 목록을 조회합니다 |
| `POST` | `/api/templates` | 템플릿을 생성합니다 |
| `DELETE` | `/api/templates/{name}` | 템플릿을 삭제합니다 |

### 관리자 (Admin)

| 메서드 | 엔드포인트 | 설명 |
|--------|-----------|------|
| `GET` | `/api/admin/jobs` | 전체 활성 작업을 조회합니다 |
| `DELETE` | `/api/admin/jobs/{job_id}` | 작업을 강제 삭제합니다 |
| `POST` | `/api/admin/jobs/{job_id}/retry` | 실패한 작업을 재시도합니다 |
| `GET` | `/api/admin/regions` | 리전별 용량을 조회합니다 |
| `PUT` | `/api/admin/regions/{region}/capacity` | 리전 용량을 업데이트합니다 |
| `GET` | `/api/admin/stats` | 작업 수 및 큐 깊이를 조회합니다 |

### 헬스 체크 및 메트릭

| 메서드 | 엔드포인트 | 설명 |
|--------|-----------|------|
| `GET` | `/healthz` | 라이브니스 프로브입니다 |
| `GET` | `/readyz` | 레디니스 프로브입니다 (Redis 상태 확인) |
| `GET` | `/metrics` | Prometheus 메트릭을 제공합니다 |

## 기여 방법

1. 저장소를 포크합니다.
2. `main` 브랜치에서 기능 브랜치를 생성합니다.
3. 기존 코드 컨벤션을 따릅니다:
   - Python: `ruff` (E, F, I, N, W 규칙), 줄 길이 100, async 우선
   - TypeScript: strict 모드, 경로 별칭 `@/`
   - Git: 컨벤셔널 커밋 (`feat:`, `fix:`, `docs:` 등)
4. 새로운 기능에 대한 테스트를 추가합니다.
5. 제출 전에 린트 및 타입 검사를 실행합니다.
6. 명확한 설명과 함께 Pull Request를 생성합니다.

## 라이선스

이 프로젝트는 MIT 라이선스로 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하십시오.

## 연락처

- 관리자: GPU Spot Lotto Team
- 이슈: GitHub Issues 탭에서 버그 보고 또는 기능 요청을 제출하십시오.

<!-- harness-eval-badge:start -->
![Harness Score](https://img.shields.io/badge/harness-6.6%2F10-orange)
![Harness Grade](https://img.shields.io/badge/grade-C-orange)
![Last Eval](https://img.shields.io/badge/eval-2026--04--07-blue)
<!-- harness-eval-badge:end -->
