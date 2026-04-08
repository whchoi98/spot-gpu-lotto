# GPU Spot Lotto — 설계 전략서

> 3개 리전(us-east-1, us-east-2, us-west-2)의 GPU Spot 가격을 실시간 모니터링하고,
> 사용자 요청 시 가장 저렴한 리전에 GPU Pod를 배치한 뒤 작업 완료 시 자동 회수하는 시스템.
>
> 메인 프로덕션: ap-northeast-2 (서울)

---

## 1. 시스템 아키텍처

```
                          ap-northeast-2 (서울, 메인 프로덕션)
                          ┌──────────────────────────────────────┐
                          │  사용자 → API Server (FastAPI)        │
                          │     │          ↓                      │
                          │     │       Redis                     │
                          │     │   ┌────┴────┐                   │
                          │     │ Sorted Set  List (Job Queue)    │
                          │     │ (가격 DB)       ↓               │
                          │     │          Dispatcher              │
                          │     │          Price Watcher           │
                          │     │              │                   │
                          │     │         S3 허브 버킷             │
                          │     │ (모델/데이터셋/결과/체크포인트)   │
                          │     │                                  │
                          │     │  AgentCore Runtime (us-east-1)   │
                          │     └──▶ Strands AI Agent              │
                          │          (자연어 → 도구 호출)          │
                          │              │                         │
                          │         AgentCore Gateway              │
                          │          (MCP ↔ REST 변환)             │
                          └──────────┬─────────────────────────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              ▼                      ▼                      ▼
     ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
     │   us-east-1     │  │   us-east-2     │  │   us-west-2     │
     │   EKS + Karpenter│  │   EKS + Karpenter│  │   EKS + Karpenter│
     │   GPU Spot Pool │  │   GPU Spot Pool │  │   GPU Spot Pool │
     │        │        │  │        │        │  │        │        │
     │  FSx for Lustre │  │  FSx for Lustre │  │  FSx for Lustre │
     │   (S3 캐시)     │  │   (S3 캐시)     │  │   (S3 캐시)     │
     └─────────────────┘  └─────────────────┘  └─────────────────┘
```

---

## 2. 구성 요소

### 2.1 컴포넌트 목록

| 컴포넌트 | 파일 | 역할 |
|----------|------|------|
| Price Watcher | `src/price_watcher/` | 3개 리전 Spot 가격을 60초마다 수집 → Redis Sorted Set |
| Dispatcher | `src/dispatcher/` | 큐에서 작업을 꺼내 최저가 리전에 Pod 생성 + 완료 Pod 회수 |
| API Server | `src/api_server/` | FastAPI — 사용자 요청 접수, 가격 조회, 작업 상태 확인 |
| Karpenter NodePool | `k8s/karpenter-gpu-spot.yaml` | GPU Spot 전용 NodePool (3개 리전 공통) |
| FSx PV/PVC | `k8s/fsx-lustre-pv.yaml` | FSx for Lustre 볼륨 (고성능 I/O) |
| S3 PV/PVC | `k8s/s3-mountpoint-pv.yaml` | S3 Mountpoint 볼륨 (간편 접근) |
| 클러스터 설정 | `setup-clusters.sh` | 3개 리전 EKS 클러스터 일괄 생성 |
| 스토리지 설정 | `setup-storage.sh` | S3 허브 버킷 + 리전별 FSx for Lustre 생성 |
| AI Agent | `src/agent/` | Strands 기반 AI 에이전트 — 자연어로 GPU 작업 관리 |
| AgentCore Runtime | `.bedrock_agentcore.yaml` | 서버리스 에이전트 배포 (Amazon Bedrock AgentCore) |
| AgentCore Gateway | `openapi-gateway.json` | MCP Protocol 게이트웨이 — REST API를 MCP 도구로 변환 |

### 2.2 Redis 데이터 구조

```
gpu:spot:prices       (Sorted Set)  리전:인스턴스타입 → 가격 (자동 정렬)
gpu:spot:updated_at   (String)      마지막 가격 갱신 시각
gpu:job:queue         (List)        대기 중인 작업 큐
gpu:jobs:<id>         (Hash)        개별 작업 상태 (region, status, pod_name, ...)
gpu:active_jobs       (Set)         실행 중인 작업 ID 목록
gpu:capacity:<region> (String)      리전별 가용 GPU 슬롯 카운터
```

---

## 3. 핵심 동작 흐름

### 3.1 가격 수집 (Price Watcher)

```
매 60초:
  for region in [us-east-1, us-east-2, us-west-2]:
    boto3 → describe_spot_price_history(g6.xlarge, g5.xlarge)
    ZADD gpu:spot:prices <price> <region:instance_type>
```

- Redis Sorted Set은 score(가격) 기준 자동 정렬
- `ZRANGE gpu:spot:prices 0 0` → O(1)로 최저가 조회

### 3.2 작업 배치 (Dispatcher)

```
1. BRPOP gpu:job:queue          ← 큐에서 작업 대기
2. ZRANGE gpu:spot:prices 0 0   ← 최저가 리전 선택
3. DECR gpu:capacity:<region>   ← 용량 atomic 차감
   - 용량 부족 시 → 차선 리전으로 폴백
4. K8s API → Pod 생성 (해당 리전 EKS)
5. HSET gpu:jobs:<id> ...       ← 상태 기록
```

### 3.3 작업 회수 (Reaper)

```
매 10초:
  for job_id in SMEMBERS gpu:active_jobs:
    K8s API → Pod 상태 확인
    if Succeeded or Failed:
      Pod 삭제
      INCR gpu:capacity:<region>   ← 용량 반환
      상태 업데이트 (succeeded/failed)
      SREM gpu:active_jobs <id>
```

---

## 4. 크로스 리전 스토리지 전략

### 4.1 설계 원칙

메인 프로덕션(서울)과 Spot 리전(미국 3곳) 간 데이터 공유가 필요하다.
S3를 중앙 허브로 사용하고, 각 Spot 리전에 로컬 캐시를 두는 허브-스포크 구조를 채택한다.

### 4.2 데이터 흐름

```
서울 (ap-northeast-2)
  │
  │  사용자가 모델/데이터셋을 S3에 업로드
  ▼
S3 버킷 (서울) ─── 글로벌 접근 가능 ───┐
  │                                      │
  │  AutoImport (S3→FSx 자동 동기화)     │  S3 Mountpoint (직접 마운트)
  ▼                                      ▼
us-east-1 FSx Lustre              us-east-2 S3 Mount
us-east-2 FSx Lustre              us-west-2 S3 Mount
us-west-2 FSx Lustre
     │                                   │
     ▼                                   ▼
  GPU Pod                             GPU Pod
  /data/models  (읽기)               /data/models  (읽기)
  /data/results (쓰기 → S3 write-back) /data/results (쓰기 → S3 직접)
     │                                   │
     └───────────── 결과 ────────────────┘
                     ▼
              서울에서 결과 조회
```

### 4.3 스토리지 모드 선택 기준

| | S3 Mountpoint (간단) | FSx for Lustre + S3 (고성능) |
|---|---|---|
| 설정 난이도 | 낮음 (CSI 드라이버만) | 중간 (FSx 생성 + S3 연동) |
| 읽기 성능 | S3 직접 접근, 크로스 리전 레이턴시 | 로컬 SSD 캐시, 매우 빠름 |
| 쓰기 성능 | S3 직접 쓰기 | FSx 로컬 → S3 write-back |
| 비용 | S3 요청 + 전송 비용만 | FSx 스토리지 추가 (~$140/TB/월) |
| 적합한 경우 | 모델 로딩 1회, 짧은 추론 | 반복 읽기, 대용량 학습, 체크포인팅 |

작업 제출 시 `storage_mode` 파라미터로 선택:

```json
{
  "user_id": "user1",
  "image": "my-training:latest",
  "instance_type": "g6.xlarge",
  "storage_mode": "fsx"
}
```

### 4.4 S3 버킷 구조

```
s3://gpu-lotto-data-<account-id>/
  ├── models/           ← 학습된 모델 가중치 (서울에서 업로드)
  ├── datasets/         ← 학습 데이터셋
  ├── checkpoints/      ← Spot 중단 대비 체크포인트
  └── results/          ← 작업 결과 (각 리전에서 업로드)
       ├── us-east-1/
       ├── us-east-2/
       └── us-west-2/
```

### 4.5 Pod 내부 마운트 경로

```
/data/models/       ← 읽기 전용 (모델, 데이터셋)
/data/results/      ← 읽기/쓰기 (결과 업로드)
```

---

## 5. EKS 인프라 설계

### 5.1 클러스터 구성

| 항목 | 설정 |
|------|------|
| 클러스터 모드 | EKS Auto Mode (Karpenter 내장) |
| K8s 버전 | 1.31 |
| 노드 AMI | Bottlerocket Accelerated (GPU 드라이버 + Device Plugin 내장) |
| 네임스페이스 | `gpu-jobs` (GPU 작업 전용) |

### 5.2 Karpenter NodePool 설정

```yaml
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot"]                    # Spot 전용
  - key: karpenter.k8s.aws/instance-category
    operator: In
    values: ["g"]                       # G 시리즈 (GPU)
  - key: karpenter.k8s.aws/instance-generation
    operator: Gt
    values: ["4"]                       # g5, g6 이상
  - key: karpenter.k8s.aws/instance-size
    operator: In
    values: ["xlarge", "2xlarge"]
taints:
  - key: nvidia.com/gpu
    effect: NoSchedule                  # GPU 워크로드만 스케줄링
```

- 유휴 노드 30초 후 자동 축소 (`consolidateAfter: 30s`)
- 노드 최대 수명 2시간 (`expireAfter: 2h`)
- GPU 리소스 상한: 16 GPU

### 5.3 Spot 중단 대응

| 계층 | 대응 |
|------|------|
| Karpenter | Spot 중단 시 자동으로 대체 노드 프로비저닝 |
| EKS Auto Mode | Node Monitoring Agent가 GPU 장애 감지 → 10분 내 자동 복구 |
| 애플리케이션 | 체크포인트를 `/data/checkpoints/`에 주기적 저장 |
| Dispatcher | Pod 실패 감지 → 다른 리전에 재배치 가능 |

---

## 6. 비용 최적화 전략

### 6.1 현재 Spot 가격 (2026-04-03 기준, g6.xlarge)

| 리전 | Spot 가격/시간 | On-Demand 대비 절감률 |
|------|---------------|---------------------|
| us-east-2 | $0.2261 | ~70% |
| us-east-1 | $0.3608 | ~52% |
| us-west-2 | $0.4402 | ~42% |

### 6.2 비용 절감 포인트

- 멀티 리전 Spot: 항상 최저가 리전에 배치하여 단일 리전 대비 추가 절감
- Karpenter 자동 축소: 작업 없으면 30초 후 노드 제거 → 유휴 비용 0
- FSx Scratch-SSD: Persistent 대비 저렴, Spot 워크로드와 수명 일치
- S3 Mountpoint: 짧은 작업은 FSx 없이 S3 직접 접근으로 스토리지 비용 절감

### 6.3 예상 비용 구조

```
GPU 컴퓨팅:  Spot 가격 × 사용 시간 (유휴 시 0)
스토리지:    S3 저장 비용 + (선택 시) FSx for Lustre
데이터 전송: 서울↔미국 리전 간 S3 전송 비용
Redis:      ElastiCache (프로덕션) 또는 EC2 자체 호스팅
EKS:       클러스터당 $0.10/hr × 3 = $0.30/hr (고정)
```

---

## 7. 프로덕션 체크리스트

### 7.1 인프라

- [ ] 3개 리전 EKS 클러스터 생성 (`setup-clusters.sh`)
- [ ] 각 리전 Karpenter GPU Spot NodePool 적용
- [ ] FSx for Lustre CSI 드라이버 설치 (각 리전)
- [ ] Mountpoint for S3 CSI 드라이버 설치 (각 리전)
- [ ] S3 허브 버킷 생성 + FSx 연동 (`setup-storage.sh`)
- [ ] 리전별 kubeconfig 설정

### 7.2 보안

- [ ] IRSA (IAM Roles for Service Accounts) 설정 — Pod에서 S3/FSx 접근
- [ ] API Server 앞에 ALB + 인증 (Cognito 또는 API Key)
- [ ] Redis를 ElastiCache로 교체 (암호화, VPC 내부)
- [ ] EKS 클러스터 엔드포인트 프라이빗 접근 설정

### 7.3 모니터링

- [ ] CloudWatch로 리전별 Spot 가격 추이 대시보드
- [ ] GPU 활용률 메트릭 (DCGM-Exporter → CloudWatch)
- [ ] 작업 성공률 / 실패율 / 평균 대기 시간 메트릭
- [ ] Spot 중단 빈도 모니터링
- [ ] S3 ↔ FSx 동기화 지연 모니터링

### 7.4 운영

- [ ] 작업 타임아웃 설정 (무한 실행 방지)
- [ ] 체크포인팅 가이드 문서화 (사용자용)
- [ ] Spot 중단 시 자동 재배치 로직 검증
- [ ] 부하 테스트 (동시 작업 N개)

---

## 8. API 사용법

```bash
# 현재 Spot 가격 조회
curl http://localhost:8000/prices

# GPU 작업 제출 (최저가 리전에 자동 배치)
curl -X POST http://localhost:8000/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user1",
    "image": "my-ml-image:latest",
    "instance_type": "g6.xlarge",
    "storage_mode": "fsx"
  }'

# 작업 상태 확인
curl http://localhost:8000/jobs/{job_id}

# 작업 취소
curl -X DELETE http://localhost:8000/jobs/{job_id}
```

---

## 9. 빠른 시작

```bash
# 1. 3개 리전에 EKS 클러스터 생성
./setup-clusters.sh

# 2. S3 + FSx 스토리지 설정
./setup-storage.sh

# 3. Redis 실행
docker run -d --name redis -p 6379:6379 redis:7-alpine

# 4. 의존성 설치
pip install -r requirements.txt

# 5. 가격 수집기 시작
python price_watcher.py &

# 6. 디스패처 시작
python dispatcher.py &

# 7. API 서버 시작
uvicorn api_server:app --host 0.0.0.0 --port 8000
```

---

## 10. AI 에이전트 아키텍처

### 10.1 개요

Strands Agents SDK 기반의 AI 에이전트가 자연어로 GPU Spot 작업을 관리한다.
`dispatch_mode: agent` 설정 시, 규칙 기반 디스패처 대신 AI 에이전트가 가격/장애 이력을 분석하여 최적 리전을 선택한다.

### 10.2 에이전트 도구 (Tools)

| 도구 | 설명 |
|------|------|
| `check_spot_prices` | Redis Sorted Set에서 현재 Spot 가격 조회 |
| `submit_gpu_job` | Redis 큐에 작업 제출 |
| `get_job_status` | 특정 작업 상태 조회 |
| `list_active_jobs` | 실행 중인 전체 작업 목록 |
| `get_failure_history` | 최근 실패 작업 이력 (리전별 안정성 판단) |

### 10.3 AgentCore Runtime

```
사용자 (자연어)
  │
  ▼
AgentCore Runtime (서버리스, us-east-1)
  │
  ├── Strands Agent (Claude Sonnet 모델)
  │     ├── 시스템 프롬프트 (GPU 인스턴스 매핑, 결정 가이드라인)
  │     └── @tool 함수 5개 (Redis 직접 접근)
  │
  └── 배포: agentcore deploy (direct_code_deploy)
```

- 런타임 플랫폼: `linux/arm64`, Python 3.11
- 의존성: `requirements.txt` (프로젝트 루트)에서 자동 감지
- 소스 경로: `/var/task/src/agent/app.py`
- 네트워크: PUBLIC 모드 (VPC 미연결 — Redis 접근 불가, 프로덕션은 VPC 필요)

### 10.4 AgentCore Gateway (MCP Protocol)

REST API를 MCP(Model Context Protocol) 도구로 노출하는 프로토콜 브릿지.
외부 에이전트나 MCP 클라이언트가 GPU Spot Lotto API를 도구처럼 사용 가능.

```
외부 에이전트/MCP 클라이언트
  │
  ▼
AgentCore Gateway (MCP ↔ REST 변환)
  │  OpenAPI 스펙 기반 자동 도구 생성
  ▼
GPU Spot Lotto API (CloudFront → ALB → FastAPI)
```

노출되는 MCP 도구:
- `get_api_prices` — Spot 가격 조회
- `post_api_jobs` — 작업 제출
- `get_api_jobs_by_job_id` — 작업 상태 확인
- `delete_api_jobs_by_job_id` — 작업 취소
- `get_api_admin_jobs` — 전체 작업 목록
- `get_api_admin_stats` — 시스템 통계

---

## 11. 향후 확장 고려사항

- 리전 추가: `REGIONS` 리스트에 추가하고 EKS 클러스터 + FSx 생성만 하면 자동 확장
- GPU 타입 다양화: g6e (L40S), p5 (H100) 등 추가 가능
- 스케줄링 고도화: AI 에이전트 모드 (`dispatch_mode: agent`)로 구현 완료. 향후 Spot 중단 빈도, 대기 시간 등 추가 가중치 반영 가능
- 멀티 테넌시: 사용자별 GPU 쿼터, 우선순위 큐 도입
- 비용 대시보드: 사용자별/리전별 GPU 사용량 및 비용 리포트

---

## 12. 사용자 요청 트리거 및 동작 흐름 (상세)

### 12.1 시퀀스 다이어그램

```
사용자                API Server           Redis                Dispatcher           EKS (최저가 리전)
  │                      │                  │                      │                      │
  │ 1. POST /jobs        │                  │                      │                      │
  │ {image,instance_type} │                  │                      │                      │
  │ ───────────────────▶ │                  │                      │                      │
  │                      │ 2. LPUSH queue   │                      │                      │
  │                      │ ───────────────▶ │                      │                      │
  │                      │ (Pub/Sub 대기)    │ 3. BRPOP queue       │                      │
  │                      │                  │ ◀──────────────────── │                      │
  │                      │                  │                      │                      │
  │                      │                  │ 4. ZRANGE prices 0 0 │                      │
  │                      │                  │ ─────────────────▶   │ 최저가 리전 확인       │
  │                      │                  │                      │                      │
  │                      │                  │ 5. DECR capacity     │                      │
  │                      │                  │ ─────────────────▶   │ 용량 atomic 차감      │
  │                      │                  │                      │                      │
  │                      │                  │                      │ 6. Pod 생성           │
  │                      │                  │                      │ ───────────────────▶  │
  │                      │                  │                      │                      │ Karpenter:
  │                      │                  │ 7. HSET jobs:<id>    │                      │ Spot 노드
  │                      │                  │ ─────────────────▶   │ 상태 기록             │ 자동 프로비저닝
  │                      │                  │                      │                      │
  │                      │ 8. PUBLISH result │                      │                      │
  │                      │ ◀─────────────── │                      │                      │
  │ 9. 응답 반환          │                  │                      │                      │
  │ {job_id,region,price}│                  │                      │                      │
  │ ◀─────────────────── │                  │                      │                      │
  │                      │                  │                      │                      │
  │                      │                  │                      │   (GPU 작업 실행중)    │
  │                      │                  │                      │        ...            │
  │ 10. GET /jobs/{id}   │                  │                      │                      │
  │ (폴링으로 상태 확인)  │ HGETALL jobs:<id>│                      │                      │
  │ ───────────────────▶ │ ───────────────▶ │                      │                      │
  │ ◀─────────────────── │                  │                      │                      │
  │                      │                  │                      │ 11. Reaper (10초 주기) │
  │                      │                  │                      │ Pod 상태 확인          │
  │                      │                  │                      │ ◀──────────────────── │
  │                      │                  │                      │ Pod: Succeeded        │
  │                      │                  │                      │                      │
  │                      │                  │ 12. Pod 삭제          │                      │
  │                      │                  │     INCR capacity    │ 용량 반환             │
  │                      │                  │     status→succeeded │                      │
  │                      │                  │     SREM active_jobs │                      │
  │                      │                  │                      │                      │
  │ 13. GET /jobs/{id}   │                  │                      │ 14. Karpenter         │
  │ → status: succeeded  │                  │                      │ 유휴 30초 후 노드 축소 │
  │ 결과: S3에서 조회     │                  │                      │ → 비용 0              │
```

### 12.2 단계별 상세 설명

#### Phase 1: 요청 접수

| 단계 | 주체 | 동작 | 기술 상세 |
|------|------|------|----------|
| 1 | 사용자 | `POST /jobs` API 호출 | FastAPI 엔드포인트, JSON body |
| 2 | API Server | 작업을 Redis 큐에 추가 | `LPUSH gpu:job:queue <job_json>` |
| | API Server | 결과 알림 대기 | Redis Pub/Sub 구독 (`gpu:result:<user_id>`) |

```bash
curl -X POST http://localhost:8000/jobs \
  -H "Content-Type: application/json" \
  -d '{"user_id":"user1", "image":"my-ml:latest", "instance_type":"g6.xlarge"}'
```

#### Phase 2: 최저가 리전 선택 및 배치

| 단계 | 주체 | 동작 | 기술 상세 |
|------|------|------|----------|
| 3 | Dispatcher | 큐에서 작업 꺼냄 | `BRPOP gpu:job:queue` (블로킹 대기) |
| 4 | Dispatcher | 최저가 리전 조회 | `ZRANGE gpu:spot:prices 0 -1 WITHSCORES` → 인스턴스 타입 필터링 |
| 5 | Dispatcher | 용량 확인 및 차감 | `DECR gpu:capacity:<region>` (atomic) |
| | | 용량 부족 시 | 차선 리전으로 자동 폴백 |
| 6 | Dispatcher | Pod 생성 | K8s API → 해당 리전 EKS 클러스터에 Pod 생성 |
| 7 | Dispatcher | 상태 기록 | `HSET gpu:jobs:<id> region/status/pod_name/...` |
| 8-9 | Dispatcher | 결과 알림 | `PUBLISH gpu:result:<user_id>` → API Server가 사용자에게 응답 |

최저가 선택 로직:
```
Redis Sorted Set (가격순 자동 정렬):
  score=0.2261  member="us-east-2:g6.xlarge"   ← 1순위
  score=0.3608  member="us-east-1:g6.xlarge"   ← 2순위 (폴백)
  score=0.4402  member="us-west-2:g6.xlarge"   ← 3순위 (폴백)
```

#### Phase 3: GPU 작업 실행

| 단계 | 주체 | 동작 | 기술 상세 |
|------|------|------|----------|
| | Karpenter | Spot 노드 프로비저닝 | Pod 요청 감지 → g6.xlarge Spot 인스턴스 자동 생성 |
| | EKS | GPU 노드 준비 | Bottlerocket AMI (GPU 드라이버 내장) 부팅 |
| | Pod | 작업 실행 | 컨테이너 시작, /data/models 마운트, GPU 작업 수행 |
| | Pod | 결과 저장 | /data/results/ 에 쓰기 → S3에 자동 반영 |

Pod 내부 마운트:
```
/data/models/    ← S3 또는 FSx (읽기 전용, 모델/데이터셋)
/data/results/   ← S3 또는 FSx (읽기/쓰기, 결과 업로드)
```

#### Phase 4: 상태 확인

| 단계 | 주체 | 동작 | 기술 상세 |
|------|------|------|----------|
| 10 | 사용자 | 상태 폴링 | `GET /jobs/{job_id}` → Redis Hash 조회 |

응답 예시:
```json
{
  "region": "us-east-2",
  "status": "running",
  "pod_name": "gpu-job-a1b2c3d4",
  "instance_type": "g6.xlarge",
  "created_at": "1743724800"
}
```

#### Phase 5: 작업 완료 및 회수

| 단계 | 주체 | 동작 | 기술 상세 |
|------|------|------|----------|
| 11 | Reaper | Pod 상태 확인 | 10초 주기로 `SMEMBERS gpu:active_jobs` 순회 |
| 12 | Reaper | 완료 Pod 회수 | Pod 삭제 + `INCR capacity` + 상태 업데이트 |
| 13 | 사용자 | 최종 결과 확인 | `GET /jobs/{id}` → `status: succeeded` |
| 14 | Karpenter | 노드 축소 | 유휴 30초 후 Spot 노드 자동 종료 → 비용 0 |

#### Phase 6: 결과 조회 (서울)

| 단계 | 주체 | 동작 |
|------|------|------|
| | 사용자 | 서울에서 S3 결과 조회 |
| | | `s3://gpu-lotto-data-xxx/results/<region>/<job_id>/` |

### 12.3 예외 처리 흐름

#### Spot 중단 발생 시

```
EKS 노드 중단 알림 (2분 전)
  → Karpenter: 대체 Spot 노드 자동 프로비저닝
  → Pod: 체크포인트 저장 (/data/checkpoints/)
  → Reaper: Pod 상태 Failed 감지
  → Dispatcher: (선택) 다른 리전에 재배치 가능
```

#### 전체 리전 용량 부족 시

```
Dispatcher:
  1순위 us-east-2 → DECR capacity → 음수 → INCR 복원
  2순위 us-east-1 → DECR capacity → 음수 → INCR 복원
  3순위 us-west-2 → DECR capacity → 음수 → INCR 복원
  → 응답: {"error": "All regions at capacity"}
  → 사용자: 잠시 후 재시도
```

#### 작업 취소 시

```
사용자: DELETE /jobs/{job_id}
  → Redis: status → "cancelling"
  → Reaper: cancelling 상태 감지 → Pod 강제 삭제 → 용량 반환
```

### 12.4 백그라운드 프로세스 요약

| 프로세스 | 주기 | 역할 |
|----------|------|------|
| Price Watcher | 60초 | 3개 리전 Spot 가격 수집 → Redis Sorted Set 갱신 |
| Dispatcher (Queue) | 상시 (BRPOP) | 큐에서 작업 꺼내 최저가 리전에 배치 |
| Dispatcher (Reaper) | 10초 | 완료/실패 Pod 감지 → 삭제 + 용량 반환 |
| Karpenter | 상시 | Pod 요청 시 Spot 노드 생성, 유휴 시 축소 |
