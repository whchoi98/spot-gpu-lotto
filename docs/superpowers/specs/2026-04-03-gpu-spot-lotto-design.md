# GPU Spot Lotto - Production Design Spec

> 3개 리전(us-east-1, us-east-2, us-west-2)의 GPU Spot 가격을 실시간 모니터링하고,
> 사용자 요청 시 가장 저렴한 리전에 GPU Pod를 배치한 뒤 작업 완료 시 자동 회수하는 시스템.
>
> 메인 프로덕션: ap-northeast-2 (서울)

---

## 1. 결정 사항 요약

| 항목 | 선택 |
|------|------|
| 구현 범위 | 풀 프로덕션 |
| 구현 전략 | 마이크로서비스 (3개 백엔드 + 1개 프론트엔드) |
| 인프라 관리 | Terraform |
| 인증/보안 | Cognito + ALB + CloudFront (Prefix List SG) |
| 모니터링 | Prometheus + Grafana (셀프호스팅, 서울 EKS) |
| 컨트롤 플레인 | 서울 리전 EKS 클러스터 |
| 멀티 테넌시 | 단일 테넌트, 역할 기반 접근 (admin/user) |
| Spot 중단 대응 | 체크포인트 + 단순 재시작 양쪽 지원 |
| CI/CD | GitHub Actions |
| GPU 인스턴스 | Tier 1~3 (g6/g5, g6e, g5.12xl/48xl) |
| 프론트엔드 | React + Vite + Tailwind + shadcn/ui |
| IAM 인증 | Pod Identity (IRSA 아님) |

---

## 2. 시스템 아키텍처

```
                          ap-northeast-2 (서울, 컨트롤 플레인)
                          ┌───────────────────────────────────────────┐
                          │                                           │
                          │  CloudFront (WAF, Shield Standard)        │
                          │       │                                   │
                          │       │ Prefix List SG                    │
                          │       ▼                                   │
                          │  ALB (Cognito 인증)                       │
                          │    ├── /api/* → API Server                │
                          │    └── /*     → Frontend (Nginx)          │
                          │                                           │
                          │  EKS (서울)                                │
                          │  ├── API Server (FastAPI)                 │
                          │  ├── Dispatcher                           │
                          │  ├── Price Watcher                        │
                          │  ├── Frontend (Nginx + React SPA)         │
                          │  ├── Prometheus + Grafana                 │
                          │  └── ElastiCache Redis                    │
                          │                                           │
                          │  S3 허브 버킷                              │
                          │  (models/datasets/results/checkpoints)    │
                          └──────────────┬────────────────────────────┘
                                         │
              ┌──────────────────────────┼──────────────────────────┐
              ▼                          ▼                          ▼
     ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
     │   us-east-1     │      │   us-east-2     │      │   us-west-2     │
     │   EKS + Karpenter│      │   EKS + Karpenter│      │   EKS + Karpenter│
     │   GPU Spot Pool │      │   GPU Spot Pool │      │   GPU Spot Pool │
     │   Prom Agent    │      │   Prom Agent    │      │   Prom Agent    │
     │   DCGM Exporter │      │   DCGM Exporter │      │   DCGM Exporter │
     │   FSx Lustre    │      │   FSx Lustre    │      │   FSx Lustre    │
     │   S3 Mountpoint │      │   S3 Mountpoint │      │   S3 Mountpoint │
     └─────────────────┘      └─────────────────┘      └─────────────────┘
```

---

## 3. 프로젝트 구조

```
spot-gpu-lotto/
├── terraform/
│   ├── modules/
│   │   ├── vpc/                  # VPC (서울 + 3개 Spot 리전)
│   │   ├── eks/                  # EKS Auto Mode + Pod Identity Agent addon
│   │   ├── karpenter/            # GPU Spot NodePool + EC2NodeClass
│   │   ├── elasticache/          # Redis 7 (TLS, 프라이빗 서브넷)
│   │   ├── s3/                   # 허브 버킷 + 수명 주기 정책
│   │   ├── fsx/                  # FSx for Lustre (리전당 1개, AutoExport 포함)
│   │   ├── cognito/              # User Pool + App Client + 커스텀 속성 (role)
│   │   ├── alb/                  # ALB + Cognito 리스너 + Prefix List SG
│   │   ├── cloudfront/           # CF 배포 + WAF WebACL + 캐시 정책
│   │   └── monitoring/           # Helm release: kube-prometheus-stack, DCGM
│   ├── envs/
│   │   ├── dev/                  # 개발 환경
│   │   └── prod/                 # 프로덕션 환경
│   ├── backend.tf
│   └── versions.tf
├── src/
│   ├── common/
│   │   ├── config.py             # pydantic-settings 환경변수 설정
│   │   ├── redis_client.py       # ElastiCache TLS 연결 + 커넥션 풀
│   │   ├── k8s_client.py         # Pod Identity 기반 크로스 클러스터 접근
│   │   ├── models.py             # 공유 데이터 모델 (Job, Price 등)
│   │   └── logging.py            # structlog JSON 포맷
│   ├── api_server/
│   │   ├── main.py               # FastAPI 앱 + 라우터
│   │   ├── routes/
│   │   │   ├── jobs.py           # 작업 CRUD + SSE 스트림 + 로그 스트리밍
│   │   │   ├── prices.py         # 가격 조회
│   │   │   ├── upload.py         # S3 presigned upload URL 생성
│   │   │   ├── templates.py      # 작업 템플릿 CRUD
│   │   │   ├── admin.py          # 관리자 전용 엔드포인트
│   │   │   └── health.py         # /healthz, /readyz
│   │   ├── auth.py               # Cognito JWT 파싱, 역할 검증 미들웨어
│   │   └── Dockerfile
│   ├── dispatcher/
│   │   ├── main.py
│   │   ├── queue_processor.py    # 큐 소비 + 배치 로직
│   │   ├── pod_builder.py        # Pod 스펙 (FSx/S3/체크포인트/환경변수)
│   │   ├── reaper.py             # 완료 회수 + Spot 재배치 + 알림 전송
│   │   └── Dockerfile
│   ├── price_watcher/
│   │   ├── main.py
│   │   ├── collector.py          # aioboto3 병렬 수집
│   │   └── Dockerfile
│   └── tests/
│       ├── unit/
│       ├── integration/
│       └── conftest.py
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   │   ├── ui/               # shadcn/ui
│   │   │   ├── layout/           # Sidebar, Header, Layout
│   │   │   ├── jobs/             # JobForm, JobTable, JobDetail, JobStatusBadge
│   │   │   ├── prices/           # PriceTable, PriceChart (recharts)
│   │   │   ├── upload/           # FileUpload (드래그&드롭 + 진행률)
│   │   │   ├── logs/            # LogViewer (터미널 스타일 로그 뷰어)
│   │   │   ├── templates/       # TemplateSelector, TemplateForm
│   │   │   ├── guide/           # InstanceGuide (인스턴스 선택 가이드)
│   │   │   └── admin/            # RegionCard, QueueDepth, UserTable
│   │   ├── pages/
│   │   │   ├── Dashboard.tsx
│   │   │   ├── Jobs.tsx
│   │   │   ├── JobNew.tsx        # 인스턴스 가이드 + 템플릿 로드
│   │   │   ├── JobDetail.tsx     # SSE 실시간 상태 + 로그 뷰어
│   │   │   ├── Templates.tsx     # 작업 템플릿 관리
│   │   │   ├── Prices.tsx
│   │   │   ├── Settings.tsx      # 사용자 설정 (webhook URL)
│   │   │   └── admin/
│   │   │       ├── AdminDashboard.tsx
│   │   │       ├── AdminJobs.tsx
│   │   │       ├── AdminRegions.tsx
│   │   │       ├── AdminUsers.tsx
│   │   │       └── AdminSettings.tsx
│   │   ├── hooks/
│   │   │   ├── useJobs.ts        # react-query CRUD
│   │   │   ├── usePrices.ts      # 30초 폴링
│   │   │   ├── useJobStream.ts   # SSE EventSource hook
│   │   │   ├── useJobLogs.ts     # SSE 로그 스트리밍 hook
│   │   │   ├── useTemplates.ts   # 템플릿 CRUD hook
│   │   │   └── useAuth.ts        # JWT 역할 확인
│   │   ├── lib/
│   │   │   ├── api.ts            # axios 인스턴스
│   │   │   └── auth.ts           # JWT 파싱
│   │   ├── App.tsx               # React Router + 역할 기반 라우트 가드
│   │   └── main.tsx
│   ├── Dockerfile                # multi-stage: build → nginx:alpine
│   ├── nginx.conf
│   ├── package.json
│   ├── tailwind.config.ts
│   ├── tsconfig.json
│   └── vite.config.ts
├── helm/
│   └── gpu-lotto/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-prod.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── namespace.yaml
│           ├── configmap.yaml
│           ├── api-server/       # deployment, service, ingress, sa, hpa
│           ├── dispatcher/       # deployment, sa, pdb
│           ├── price-watcher/    # deployment, sa
│           ├── frontend/         # deployment, service, sa
│           └── monitoring/       # servicemonitor
├── k8s/
│   ├── karpenter-gpu-spot.yaml
│   ├── fsx-lustre-pv.yaml
│   └── s3-mountpoint-pv.yaml
├── .github/
│   └── workflows/
│       ├── ci.yml                # lint + test + Docker build
│       ├── infra.yml             # Terraform plan/apply
│       └── deploy.yml            # ECR push + Helm deploy
├── docker-compose.yml            # 로컬 개발 (mock/dry-run 모드)
└── pyproject.toml
```

---

## 4. 애플리케이션 설계

### 4.1 공유 모듈 (src/common/)

**config.py** — pydantic-settings 기반 환경변수 설정:
```
redis_url, regions, instance_types, poll_interval, reap_interval,
job_timeout (7200s), max_retries (2), capacity_per_region (16)
```

**k8s_client.py** — Pod Identity + `aws eks get-token`으로 Spot 리전 EKS 동적 인증. 리전별 클라이언트 캐싱.

**redis_client.py** — ElastiCache TLS 연결, 커넥션 풀링, 헬스체크 ping.

**logging.py** — structlog JSON 포맷 → stdout → Fluent Bit → CloudWatch Logs.

### 4.2 API Server

| 엔드포인트 | 메서드 | 설명 |
|-----------|--------|------|
| `/api/prices` | GET | Spot 가격 조회 |
| `/api/jobs` | POST | 작업 제출 (즉시 job_id 반환) |
| `/api/jobs/{id}` | GET | 작업 상태 |
| `/api/jobs/{id}` | DELETE | 작업 취소 |
| `/api/jobs/{id}/stream` | GET | SSE 실시간 상태 스트림 |
| `/api/jobs/{id}/logs` | GET | Pod 로그 실시간 스트리밍 (SSE, ?follow=true&tail=100) |
| `/api/upload/presign` | POST | S3 presigned upload URL 생성 |
| `/api/templates` | GET | 내 작업 템플릿 목록 |
| `/api/templates` | POST | 작업 템플릿 저장 |
| `/api/templates/{name}` | DELETE | 작업 템플릿 삭제 |
| `/api/settings/webhook` | PUT | 사용자 웹훅 URL 설정 |
| `/api/admin/jobs` | GET | 전체 작업 (관리자) |
| `/api/admin/jobs/{id}` | DELETE | 강제 취소 (관리자) |
| `/api/admin/jobs/{id}/retry` | POST | 강제 재배치 (관리자) |
| `/api/admin/regions` | GET | 리전별 용량/상태 |
| `/api/admin/regions/{region}/capacity` | PUT | 용량 수동 조정 |
| `/api/admin/regions/{region}/enabled` | PUT | 리전 활성화/비활성화 |
| `/api/admin/stats` | GET | 통계 |
| `/api/admin/settings` | PUT | 런타임 설정 변경 |
| `/healthz` | GET | liveness (인증 제외) |
| `/readyz` | GET | readiness: Redis 연결 확인 (인증 제외) |

변경점:
- `POST /jobs`는 즉시 job_id 반환 (Pub/Sub 블로킹 제거)
- Cognito JWT에서 역할 추출하여 admin 엔드포인트 보호
- SSE로 실시간 상태 푸시
- presigned URL로 파일 업로드/결과 다운로드

### 4.3 Dispatcher

**큐 처리 (queue_processor.py):**
1. `BRPOP gpu:job:queue` (블로킹 대기)
2. 최저가 리전 선택 (`ZRANGE`, 인스턴스 타입 필터링)
3. 용량 차감 (Lua 스크립트로 atomic, 음수 방지)
4. 용량 부족 시 차선 리전 폴백 (전 리전 순회)
5. 전체 부족 시 큐에 재삽입 (retry_count 부착, max_retries 초과 시 failed)
6. Pod 생성 (해당 리전 EKS)
7. Redis Hash 상태 기록 + active_jobs Set 추가
8. Redis Pub/Sub로 상태 변경 알림 (SSE용)

**용량 관리 Lua 스크립트:**
```lua
local cap = redis.call('GET', KEYS[1])
if tonumber(cap) > 0 then
  return redis.call('DECR', KEYS[1])
else
  return -1
end
```

**Pod 스펙 생성 (pod_builder.py):**
- storage_mode에 따라 FSx 또는 S3 Mountpoint PVC 마운트
- checkpoint_enabled 시 `/data/checkpoints/<job_id>/` 마운트 + 환경변수 주입
- GPU 타입/수량에 따라 nodeSelector, resource limits 설정
- toleration: `nvidia.com/gpu: NoSchedule`
- 환경변수: `CHECKPOINT_DIR`, `CHECKPOINT_ENABLED`, `RESULT_DIR`

**Reaper (reaper.py):**
- 10초 주기로 active_jobs 순회
- Pod 상태 확인:
  - Succeeded → Pod 삭제, 용량 반환, 상태 업데이트, 웹훅 알림 전송
  - Failed (Spot 중단) → retry_count < max_retries면 다른 리전 재배치, 아니면 failed
  - Failed (기타) → failed 처리, 웹훅 알림 전송
  - cancelling → Pod 강제 삭제, 용량 반환
- 타임아웃 감지: `created_at + job_timeout` 초과 시 강제 종료
- 상태 변경마다 Redis Pub/Sub 발행 (SSE용)

### 4.4 Price Watcher

- aioboto3로 3개 리전 병렬 수집 (60초 주기)
- `ZADD`로 upsert (기존 delete→zadd 패턴 제거, 빈 set 순간 방지)
- 연속 실패 카운터 → 임계치 초과 시 Prometheus 메트릭 증가
- 수집 대상 인스턴스 타입:
  - Tier 1: g6.xlarge, g5.xlarge
  - Tier 2: g6e.xlarge, g6e.2xlarge
  - Tier 3: g5.12xlarge, g5.48xlarge

---

## 5. GPU 인스턴스 Tier

| Tier | 인스턴스 | GPU | VRAM | 용도 |
|------|---------|-----|------|------|
| 1 | g6.xlarge | 1× L4 | 24GB | 추론, 경량 작업 |
| 1 | g5.xlarge | 1× A10G | 24GB | 추론, 경량 작업 |
| 2 | g6e.xlarge | 1× L40S | 48GB | LLM 파인튜닝 (13B QLoRA, 7B 풀) |
| 2 | g6e.2xlarge | 1× L40S | 48GB | + vCPU/RAM 여유 |
| 3 | g5.12xlarge | 4× A10G | 96GB | 분산 학습, 큰 배치 |
| 3 | g5.48xlarge | 8× A10G | 192GB | 대규모 모델 학습 |

Karpenter NodePool:
```yaml
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot"]
  - key: karpenter.k8s.aws/instance-category
    operator: In
    values: ["g"]
  - key: karpenter.k8s.aws/instance-generation
    operator: Gt
    values: ["4"]
  - key: karpenter.k8s.aws/instance-size
    operator: In
    values: ["xlarge", "2xlarge", "12xlarge", "48xlarge"]
taints:
  - key: nvidia.com/gpu
    effect: NoSchedule
```

- 유휴 노드 30초 후 자동 축소 (`consolidateAfter: 30s`)
- 노드 최대 수명 2시간 (`expireAfter: 2h`)
- GPU 리소스 상한: 16 GPU

---

## 6. Terraform 인프라

### 6.1 모듈 의존 관계

```
vpc (×4) → eks (×4) → karpenter (×3 Spot)
                    → pod_identity (×4)
                    → monitoring (서울)
vpc (서울) → elasticache
          → alb → cloudfront
s3 → fsx (×3 Spot)
cognito → alb
```

### 6.2 멀티 리전 처리

리전별 provider alias를 사용하여 모듈을 명시적으로 호출. `for_each`는 provider alias와 함께 사용 불가.

```hcl
locals {
  spot_regions   = ["us-east-1", "us-east-2", "us-west-2"]
  control_region = "ap-northeast-2"
}

provider "aws" { alias = "us_east_1"; region = "us-east-1" }
provider "aws" { alias = "us_east_2"; region = "us-east-2" }
provider "aws" { alias = "us_west_2"; region = "us-west-2" }
provider "aws" { alias = "seoul";     region = "ap-northeast-2" }
```

### 6.3 주요 모듈 설계

**EKS:**
- Auto Mode (Karpenter 내장)
- Pod Identity Agent addon 활성화
- 서울: EKS Auto Mode Only (Karpenter general-purpose, 3 nodes across 3 AZs)
- Spot 리전: EKS Auto Mode Only (Karpenter general-purpose + gpu-spot NodePool)
- 엔드포인트: 서울=프라이빗, Spot=퍼블릭+프라이빗

**Pod Identity:**
```hcl
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"
}

resource "aws_eks_pod_identity_association" "dispatcher" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "gpu-lotto"
  service_account = "dispatcher"
  role_arn        = aws_iam_role.dispatcher.arn
}
```

| Pod | Service Account | IAM 권한 |
|-----|----------------|----------|
| api-server | api-server | S3 GetObject/PutObject (results/, models/, datasets/) + EKS DescribeCluster + STS AssumeRole (로그 스트리밍용 크로스 리전 접근) |
| dispatcher | dispatcher | EKS DescribeCluster + STS AssumeRole (크로스 리전) + S3 읽기 |
| price-watcher | price-watcher | EC2 DescribeSpotPriceHistory (3개 리전) |
| gpu-worker | gpu-worker | S3 GetObject (models/) + PutObject (results/, checkpoints/) |

**ElastiCache:**
- Redis 7, cache.r7g.large, 단일 노드
- TLS 암호화, 저장 시 암호화
- 서울 VPC 프라이빗 서브넷, EKS 노드 SG에서만 접근

**CloudFront:**
- Origin: ALB DNS (HTTPS only)
- 캐시: `GET /api/prices` → TTL 30초, 나머지 → CachingDisabled
- Custom Header: `X-Origin-Verify: <시크릿값>` (이중 확인)
- WAF WebACL: rate limiting, IP 차단, SQL injection 방어
- Shield Standard 포함 (L3/L4 DDoS)

**ALB:**
- SG: CloudFront Managed Prefix List만 인바운드 허용
```hcl
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}
```
- Cognito 인증 action → `/healthz`, `/readyz` 제외
- 경로 라우팅: `/api/*` → API Server, `/*` → Frontend
- idle timeout: 300초 (SSE 지원)

**S3 허브 버킷:**
- 서울 리전, 버저닝 활성화
- 수명 주기: results/ 90일→Glacier, checkpoints/ 7일→삭제
- 버킷 정책: Pod Identity 역할에서만 접근

**FSx for Lustre (Spot 리전당 1개):**
- SCRATCH_2, SSD, 1200GB
- AutoImportPolicy: NEW_CHANGED_DELETED (S3→FSx)
- AutoExportPolicy: NEW_CHANGED_DELETED (FSx→S3)
- CSI 드라이버: EKS addon `aws-file-fsx-csi-driver`

**S3 Mountpoint (Spot 리전):**
- CSI 드라이버: EKS addon `aws-mountpoint-s3-csi-driver`
- PV/PVC: Terraform `kubernetes_manifest`로 관리

**Terraform State:**
```
s3://gpu-lotto-tfstate-<account-id>/
  ├── prod/terraform.tfstate
  └── dev/terraform.tfstate
DynamoDB: gpu-lotto-tflock
```

---

## 7. 크로스 리전 스토리지

### 7.1 데이터 흐름

```
서울 (사용자)
  │ 웹 UI presigned upload 또는 aws s3 cp
  ▼
S3 허브 (ap-northeast-2)
  ├── models/<user_id>/
  ├── datasets/<user_id>/
  ├── checkpoints/<job_id>/    ← GPU Pod 저장
  └── results/<job_id>/        ← GPU Pod 저장
        │
  ┌─────┴──── S3 글로벌 접근 ────┐
  │                               │
  │  storage_mode="s3"            │  storage_mode="fsx"
  │  S3 Mountpoint 직접 마운트    │  FSx Lustre 캐싱
  │  /data/models/    (읽기)      │  /data/models/    (AutoImport)
  │  /data/results/   (쓰기→S3)   │  /data/results/   (AutoExport→S3)
  │  /data/checkpoints/ (읽기/쓰기)│  /data/checkpoints/ (읽기/쓰기)
  └───────────────────────────────┘
        │
        ▼
서울에서 결과 조회
  → API: GET /api/jobs/{id} → result_path + presigned_url
  → 직접: aws s3 cp s3://gpu-lotto-data-xxx/results/<job_id>/ ./
```

### 7.2 스토리지 모드 선택 기준

| | S3 Mountpoint | FSx for Lustre |
|---|---|---|
| 설정 | 간단 (CSI만) | 중간 (FSx + S3 연동) |
| 읽기 | S3 직접, 크로스 리전 레이턴시 | 로컬 SSD 캐시, 빠름 |
| 쓰기 | S3 직접 | FSx 로컬 → S3 write-back |
| 비용 | S3 요청+전송만 | FSx ~$140/TB/월 추가 |
| 적합 | 모델 로딩 1회, 짧은 추론 | 반복 읽기, 대용량 학습, 체크포인팅 |

---

## 8. Helm Chart 배포

### 8.1 구조

하나의 umbrella chart에 4개 서비스:

```
helm/gpu-lotto/templates/
├── api-server/      # deployment, service, ingress, sa, hpa
├── dispatcher/      # deployment, sa, pdb
├── price-watcher/   # deployment, sa
├── frontend/        # deployment, service, sa
└── monitoring/      # servicemonitor
```

### 8.2 주요 설정

```yaml
apiServer:
  replicas: 2
  hpa: { min: 2, max: 6, targetCPU: 70 }
  resources: { requests: {cpu: 250m, memory: 256Mi}, limits: {cpu: 500m, memory: 512Mi} }

dispatcher:
  replicas: 1       # 단일 인스턴스 (PDB로 보호)
  resources: { requests: {cpu: 250m, memory: 256Mi}, limits: {cpu: 500m, memory: 512Mi} }

priceWatcher:
  replicas: 1
  resources: { requests: {cpu: 100m, memory: 128Mi}, limits: {cpu: 200m, memory: 256Mi} }

frontend:
  replicas: 2
  resources: { requests: {cpu: 50m, memory: 64Mi}, limits: {cpu: 100m, memory: 128Mi} }
```

Dispatcher는 replicas: 1 + PDB. 다운 시 큐가 버퍼 역할, 복구 후 즉시 소비 재개.

### 8.3 ALB Ingress

```yaml
annotations:
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
  alb.ingress.kubernetes.io/certificate-arn: <ACM_ARN>
  alb.ingress.kubernetes.io/auth-type: cognito
  alb.ingress.kubernetes.io/auth-idp-cognito: >
    {"userPoolARN":"...","userPoolClientID":"...","userPoolDomain":"..."}
  alb.ingress.kubernetes.io/healthcheck-path: /healthz
  alb.ingress.kubernetes.io/idle-timeout: "300"
rules:
  - /api/* → api-server:8000
  - /*     → frontend:80
```

`/healthz`, `/readyz`는 인증 제외.

---

## 9. 보안

### 9.1 네트워크 계층

```
인터넷 → CloudFront (WAF + Shield Standard)
           │ Managed Prefix List
           ▼
         ALB (SG: Prefix List만 + X-Origin-Verify 헤더 검증)
           │ Cognito JWT
           ▼
         서울 EKS (프라이빗 서브넷)
           │ Pod Identity IAM
           ▼
         Spot 리전 EKS API (IAM 인증)
```

### 9.2 ALB Security Group

```hcl
# 인바운드: CloudFront Prefix List만
resource "aws_security_group_rule" "alb_from_cloudfront" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  security_group_id = aws_security_group.alb.id
}
```

직접 ALB 접근 차단. Prefix List + Custom Header 이중 검증.

### 9.3 Cognito 역할 기반 접근

```
User Pool: gpu-lotto-users
├── 커스텀 속성: custom:role ("admin" | "user")
├── 그룹: admins, users
├── 비밀번호: 최소 12자, 대소문자+숫자+특수문자
└── MFA: 선택적 (TOTP)
```

ALB → JWT `custom:role` → API Server에서 인가 검증.
프론트엔드는 JWT에서 역할 확인하여 UI 메뉴 분기 (UX 편의, 보안은 API 측에서 강제).

### 9.4 시크릿 관리

| 시크릿 | 저장 | 접근 |
|--------|------|------|
| Redis 인증 토큰 | Secrets Manager | ExternalSecret → K8s Secret |
| Spot 리전 인증 | Pod Identity + `aws eks get-token` | 런타임 동적 (정적 credential 없음) |
| Cognito 클라이언트 시크릿 | Secrets Manager | ALB annotation 참조 |
| Grafana admin 비밀번호 | Secrets Manager | ExternalSecret |
| X-Origin-Verify 값 | Secrets Manager | CloudFront origin custom header + ALB 규칙 |

### 9.5 이미지 보안

- ECR 이미지 스캔 (push 시 자동)
- CI에서 trivy 스캔 → HIGH/CRITICAL 시 빌드 실패
- 베이스: python:3.12-slim (백엔드), nginx:alpine (프론트엔드)
- GPU Job Pod: non-root 실행 강제 (`securityContext.runAsNonRoot: true`)

### 9.6 K8s NetworkPolicy

- API Server: ALB에서만 인바운드
- Dispatcher, Price Watcher: 인바운드 없음 (아웃바운드만)
- 공통 아웃바운드: Redis(6379), S3(443), EKS API(443)

---

## 10. 모니터링

### 10.1 스택

```
서울 EKS:
  kube-prometheus-stack → Prometheus Server + Grafana + Alertmanager
  + node-exporter, kube-state-metrics

Spot 리전 EKS (각각):
  Prometheus Agent (remote-write → 서울 Prometheus)
  + DCGM-Exporter (GPU 메트릭)
  + node-exporter
```

### 10.2 커스텀 메트릭

**API Server:**
- `gpu_lotto_jobs_submitted_total` (Counter)
- `gpu_lotto_jobs_active` (Gauge)
- `gpu_lotto_api_request_duration_seconds` (Histogram)

**Dispatcher:**
- `gpu_lotto_jobs_dispatched_total` (Counter, label: region)
- `gpu_lotto_jobs_failed_total` (Counter, label: reason)
- `gpu_lotto_jobs_retried_total` (Counter)
- `gpu_lotto_queue_depth` (Gauge)
- `gpu_lotto_region_capacity` (Gauge, label: region)
- `gpu_lotto_job_duration_seconds` (Histogram)

**Price Watcher:**
- `gpu_lotto_spot_price` (Gauge, label: region, instance_type)
- `gpu_lotto_price_fetch_errors_total` (Counter)

### 10.3 Grafana 대시보드 (4개)

1. **Operations Overview** — 작업 제출률, 성공/실패율, 큐 깊이, 리전별 활성 작업
2. **Spot Price & Cost** — 리전별 가격 추이, 리전 선택 분포, 시간당 예상 비용
3. **GPU Infrastructure** — GPU 활용률 (DCGM), 메모리 사용, Spot 중단 빈도, 노드 이벤트
4. **System Health** — API 응답 p50/p95/p99, Redis 상태, 컨트롤 플레인 리소스

### 10.4 알림

| 알림 | 조건 | 심각도 |
|------|------|--------|
| QueueBacklog | 큐 > 50 for 5m | warning |
| AllRegionsAtCapacity | 전 리전 capacity=0 for 3m | critical |
| HighSpotInterruptionRate | 재배치율 > 30% for 10m | warning |
| PriceWatcherDown | 갱신 없음 > 3m | critical |
| DispatcherDown | Pod 미실행 > 1m | critical |
| JobTimeoutSpike | 타임아웃 > 5/hr | warning |

### 10.5 로깅

- structlog JSON → stdout → Fluent Bit DaemonSet → CloudWatch Logs
- 로그 그룹: `/gpu-lotto/api-server`, `/gpu-lotto/dispatcher`, `/gpu-lotto/price-watcher`

---

## 11. CI/CD (GitHub Actions)

### 11.1 워크플로우

**ci.yml (PR 트리거):**
- lint: ruff check, ruff format --check, mypy
- test: unit (pytest + fakeredis), integration (testcontainers Redis)
- docker-build: 4개 이미지 빌드 검증 (push 안 함)

**infra.yml (terraform/ 변경):**
- PR: terraform fmt, validate, plan → PR 코멘트
- main 머지: terraform apply -auto-approve

**deploy.yml (src/ 또는 frontend/ 변경 + main 머지):**
- dorny/paths-filter로 변경된 서비스 감지
- 변경된 것만 Docker build + ECR push (태그: git SHA)
- Helm upgrade (변경된 이미지 태그만 업데이트)

### 11.2 인증

GitHub Actions → AWS: OIDC federation (시크릿 키 없음)
```hcl
module "github_actions_oidc" {
  # 권한: ECR push, EKS 접근, Terraform state S3/DynamoDB
  # 조건: repo = "org/spot-gpu-lotto", branch = "main"
}
```

### 11.3 ECR

```
<account>.dkr.ecr.ap-northeast-2.amazonaws.com/
├── gpu-lotto/api-server
├── gpu-lotto/dispatcher
├── gpu-lotto/price-watcher
└── gpu-lotto/frontend
```

이미지 수명 정책: 최근 10개 태그만 유지.

---

## 12. 웹 UI

### 12.1 접근 구조

```
CloudFront → Prefix List SG → ALB → Cognito 인증
  ├── /api/* → API Server
  └── /*     → Frontend Nginx (React SPA)
```

### 12.2 신청자 페이지

| 페이지 | 경로 | 기능 |
|--------|------|------|
| 대시보드 | `/` | 내 작업 요약, 현재 Spot 가격 |
| 작업 제출 | `/jobs/new` | 인스턴스 선택 가이드 + 이미지/스토리지/체크포인트 + 파일 업로드 |
| 작업 템플릿 | `/templates` | 자주 쓰는 작업 설정 프리셋 저장/불러오기/삭제 |
| 작업 목록 | `/jobs` | 작업 리스트 (상태 뱃지, 리전, 소요 시간) |
| 작업 상세 | `/jobs/:id` | SSE 실시간 상태, Pod 로그 실시간 조회, 결과 다운로드 |
| 가격 현황 | `/prices` | 3리전 × 인스턴스 가격 + 추이 차트 (30초 갱신) |
| 설정 | `/settings` | 웹훅 URL 설정 |

### 12.3 관리자 페이지

| 페이지 | 경로 | 기능 |
|--------|------|------|
| 운영 대시보드 | `/admin` | 전체 통계, 큐 깊이, 시스템 상태 |
| 전체 작업 | `/admin/jobs` | 모든 작업 조회, 강제 취소/재배치 |
| 리전 관리 | `/admin/regions` | 용량 설정, 활성화/비활성화 |
| 사용자 관리 | `/admin/users` | Cognito 사용자, 역할 변경 |
| 시스템 설정 | `/admin/settings` | 타임아웃, retries 등 런타임 설정 |

### 12.4 UX 핵심 기능

**SSE 실시간 상태:**
- `GET /api/jobs/{id}/stream` (text/event-stream)
- Dispatcher 상태 변경 → Redis Pub/Sub → API Server SSE → 프론트엔드 자동 갱신
- ALB idle timeout 300초

**Slack 웹훅 알림:**
- 작업 제출 시 `webhook_url` 옵션 또는 `/settings`에서 기본값 설정
- Reaper가 완료/실패 감지 시 POST 전송

**파일 업로드:**
- `POST /api/upload/presign` → S3 presigned POST URL
- 프론트엔드: 드래그&드롭 + 진행률 바
- 업로드 → 작업 폼 경로 자동 입력
- API Server Pod Identity에 models/, datasets/ PutObject 권한

**인스턴스 선택 가이드 (작업 제출 폼 내장):**
- `/jobs/new` 페이지에서 작업 유형 선택 시 인스턴스 Tier 자동 추천:

| 사용자 선택 | 추천 Tier | 추천 인스턴스 | 이유 |
|------------|----------|-------------|------|
| 추론 (이미지 분류, OCR 등) | Tier 1 | g6.xlarge (L4) | 추론 최적화, 가장 저렴 |
| 경량 파인튜닝 (7B QLoRA) | Tier 1 | g5.xlarge (A10G) | 24GB VRAM으로 충분 |
| LLM 파인튜닝 (13B+) | Tier 2 | g6e.xlarge (L40S) | 48GB VRAM 필요 |
| 대규모 학습 (분산) | Tier 3 | g5.12xlarge (4×A10G) | 멀티 GPU 병렬 |
| 대규모 모델 학습 | Tier 3 | g5.48xlarge (8×A10G) | 최대 GPU 메모리 |

- 각 Tier의 현재 Spot 가격을 실시간 표시
- 추천은 참고용이며, 사용자가 직접 변경 가능
- "잘 모르겠으면 Tier 1부터 시작하세요" 안내 메시지

**작업 템플릿:**
- 자주 쓰는 작업 설정을 프리셋으로 저장/불러오기
- Redis에 저장: `gpu:user:<user_id>:templates` (Hash)
- API:
  - `GET /api/templates` — 내 템플릿 목록
  - `POST /api/templates` — 템플릿 저장
  - `DELETE /api/templates/{name}` — 템플릿 삭제
- 템플릿 필드: name, image, instance_type, gpu_count, storage_mode, checkpoint_enabled, command
- 작업 제출 폼에서 "템플릿에서 불러오기" 드롭다운
- 기본 제공 템플릿:
  - "Quick Inference" — g6.xlarge, S3, checkpoint off
  - "LLM Fine-tune" — g6e.xlarge, FSx, checkpoint on
  - "Distributed Training" — g5.12xlarge, FSx, checkpoint on

**작업 로그 실시간 조회:**
- `/jobs/:id` 페이지에서 Pod 로그를 실시간 스트리밍
- API: `GET /api/jobs/{id}/logs?follow=true&tail=100` (text/event-stream)
- 구현:
  - API Server → Dispatcher가 기록한 region/pod_name으로 해당 리전 EKS에 접근
  - K8s API `read_namespaced_pod_log(follow=True)` → SSE로 클라이언트 전송
  - Pod 완료 후: CloudWatch Logs에서 조회 (Fluent Bit이 수집한 로그)
- 프론트엔드: 터미널 스타일 로그 뷰어 (xterm.js 또는 간단한 pre 태그 + 자동 스크롤)
- 관리자는 `/admin/jobs` 에서도 모든 작업의 로그 조회 가능

---

## 13. 테스트

### 13.1 계층

| 계층 | 대상 | 도구 |
|------|------|------|
| Unit | 비즈니스 로직 | pytest + fakeredis |
| Integration | Redis 연동, API | pytest + testcontainers |
| E2E | 전체 흐름 | docker-compose (mock/dry-run) |
| Infra | Terraform | terraform validate + tflint + checkov |

### 13.2 핵심 Unit 테스트

- 최저가 리전 선택 (동일 가격, 인스턴스 필터링)
- Lua 용량 차감 (경합, 음수 방지)
- 폴백 순회 (1→2→3→전부 부족)
- Pod 스펙 생성 (S3/FSx, 체크포인트 on/off, GPU 타입별)
- Spot 중단 재배치 (retry, 리전 제외, max_retries)

### 13.3 로컬 개발 (docker-compose.yml)

```yaml
services:
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
  api-server:
    environment:
      REDIS_URL: redis://redis:6379
      AUTH_ENABLED: "false"       # Cognito 스킵
  dispatcher:
    environment:
      REDIS_URL: redis://redis:6379
      K8S_MODE: "dry-run"         # K8s API 없이 로그만
  price-watcher:
    environment:
      REDIS_URL: redis://redis:6379
      PRICE_MODE: "mock"          # boto3 없이 모의 가격
  frontend:
    ports: ["3000:80"]
```

---

## 14. Spot 중단 대응

### 14.1 체크포인트 기반 재개 (checkpoint_enabled=true)

```
Spot 중단 (2분 전 알림)
→ Pod SIGTERM → 사용자 컨테이너가 /data/checkpoints/<job_id>/에 저장
→ Reaper: Failed 감지 + Spot 중단 확인
→ retry_count < max_retries:
    체크포인트 경로를 새 Pod에 마운트
    다른 리전에 재배치 (기존 리전 제외 우선)
    CHECKPOINT_DIR 환경변수로 경로 전달
→ retry_count >= max_retries:
    status = "failed", reason = "max_retries_exceeded"
```

### 14.2 단순 재시작 (checkpoint_enabled=false)

```
Spot 중단 → Failed → retry_count < max_retries → 처음부터 재실행
```

---

## 15. Python 프로젝트 설정

```toml
[project]
name = "gpu-spot-lotto"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115",
    "uvicorn>=0.34",
    "redis>=5.0",
    "boto3>=1.34",
    "aioboto3>=13.0",
    "kubernetes>=29.0",
    "pydantic>=2.0",
    "pydantic-settings>=2.0",
    "structlog>=24.0",
    "prometheus-client>=0.21",
    "sse-starlette>=2.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.24",
    "testcontainers[redis]>=4.0",
    "fakeredis>=2.0",
    "httpx>=0.27",
    "ruff>=0.8",
    "mypy>=1.13",
]
```

---

## 16. Redis 데이터 구조

```
gpu:spot:prices            (Sorted Set)  리전:인스턴스타입 → 가격
gpu:spot:updated_at        (String)      마지막 가격 갱신 시각
gpu:job:queue              (List)        대기 작업 큐
gpu:jobs:<id>              (Hash)        작업 상태 (region, status, pod_name, ...)
gpu:active_jobs            (Set)         실행 중 작업 ID
gpu:capacity:<region>      (String)      리전별 GPU 슬롯
gpu:user:<user_id>:webhook (String)      사용자 웹훅 URL
gpu:user:<user_id>:templates (Hash)     사용자 작업 템플릿 (name → JSON)
gpu:admin:settings         (Hash)        런타임 설정 (job_timeout, max_retries 등)
gpu:admin:regions:<region> (Hash)        리전 설정 (enabled, capacity)
```
