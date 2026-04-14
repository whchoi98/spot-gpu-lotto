# Changelog

[![English](https://img.shields.io/badge/lang-en-red.svg)](#english)
[![Korean](https://img.shields.io/badge/lang-ko-yellow.svg)](#한국어)

---

# English

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add AI Agent with Strands Agents SDK on Amazon Bedrock AgentCore Runtime for natural-language GPU job management
- Add AI Agent web chat UI (React) with Bedrock Converse API streaming via API Server (hybrid architecture per ADR-002)
- Add Agent page to frontend with markdown rendering (react-markdown + remark-gfm)
- Add `/api/agent/chat` endpoint for browser-based AI chat (Bedrock Converse streaming)
- Add agent tool split: `tools_jobs.py` (httpx → API Server) + `tools_infra.py` (boto3 → AWS APIs)
- Add `dispatch_mode` setting (`rule` | `agent`) and `agent_model` config for AI-based dispatch
- Add FSx Lustre per-region storage with envsubst-based PV templating (3 filesystems across us-east-1/2/us-west-2)
- Add `s3_bucket` setting to pydantic-settings config for S3 presigned URL generation
- Add real S3 upload and FSx auto-import/export verification to scenario 3 demo (not just animation)
- Add scenario 4 demo: AI Agent dispatch with AgentCore + Strands
- Add Grafana dashboard panels for GPU Spot Lotto metrics
- Add `REGION_CAPACITY` Prometheus gauge metric for per-region capacity tracking
- Add ADR-001 (AgentCore + Strands AI Agent) and ADR-002 (Hybrid Agent Chat Architecture)
- Add search and filter functionality to the job history table
- Add column-header sorting to the job history table
- Add About and Steps descriptions to all demo script start screens
- Add bilingual README.md (EN/KO) with shields.io badges
- Add CLAUDE.md project documentation hierarchy for AI-assisted development (12 files)
- Add pre-commit hook for secret scanning (AWS keys, API tokens, passwords)

### Changed

- Replace AgentCore Gateway (MCP) with direct httpx → API Server data path for agent tools
- Switch values-dev.yaml from dry-run/mock mode to live/live mode
- Update ARCHITECTURE.md to reflect actual implementation (20 endpoints, agent chat, no Gateway)
- Expand admin pages: AdminDashboard, AdminJobs, AdminRegions

### Fixed

- Fix presigned URL bucket reference in upload.py (`hasattr` always returned False, falling back to wrong bucket)
- Fix JSON parsing error in scenario 3 STEP 3 (concatenated JSON blobs caused `json.decoder.JSONDecodeError`)
- Fix `set -euo pipefail` safety in demo scripts (`aws s3 ls` returns non-zero when file not found)
- Fix job ID discovery in scenario 3 demo by polling the admin endpoint instead of parsing the submit response
- Fix cross-platform frontend Docker build with dedicated Dockerfile.prod for ARM-to-AMD64 compilation
- Fix 4 security critical issues identified by harness evaluation

### Removed

- Remove `src/agent/tools.py` (replaced by tools_jobs.py + tools_infra.py)
- Remove `src/tests/unit/test_agent_tools.py` (test for deleted tools.py)
- Remove AgentCore Gateway references from architecture, agent code, and documentation

## [0.1.0] - 2026-04-04

### Added

- Add multi-region GPU Spot price monitoring across us-east-1, us-east-2, and us-west-2 with 60-second polling
- Add automatic job dispatch to the cheapest available region with capacity-aware fallback
- Add job lifecycle management via REST API (submit, status, cancel, retry)
- Add SSE real-time job status streaming endpoint
- Add Spot interruption detection with automatic rescheduling and checkpoint preservation
- Add admin dashboard with job management, region capacity control, and system stats
- Add bilingual web UI (Korean/English) built with React 18, Vite, and shadcn/ui
- Add job templates for saving and reusing common configurations
- Add S3 presigned upload for training data and model files without API proxy
- Add Cognito JWT authentication with role-based access control (user/admin)
- Add Prometheus metrics endpoint for Grafana dashboards and alerting
- Add Hub-and-Spoke storage architecture with Seoul S3 hub and FSx Lustre auto-sync per spot region
- Add Karpenter GPU Spot NodePool for on-demand node provisioning (g5, g6, g6e)
- Add Helm 3 chart for EKS deployment with dev and prod value overrides
- Add Terraform IaC with 13 modules (VPC, EKS, Karpenter, ElastiCache, Cognito, ALB, CloudFront+WAF, ECR, FSx, S3, Pod Identity, GitHub OIDC, Monitoring)
- Add Docker multi-stage build and docker-compose for local development
- Add interactive demo scripts for 3 scenarios (cost-optimized dispatch, spot recovery, full lifecycle)
- Add E2E smoke test script for docker-compose stack validation

[Unreleased]: https://github.com/whchoi98/spot-gpu-lotto/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/whchoi98/spot-gpu-lotto/releases/tag/v0.1.0

---

# 한국어

이 프로젝트의 모든 주요 변경 사항은 이 파일에 기록됩니다.
이 문서는 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기반으로 하며,
[Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [Unreleased]

### Added

- Amazon Bedrock AgentCore Runtime 위의 Strands Agents SDK를 활용한 자연어 GPU 작업 관리 AI 에이전트 추가
- Bedrock Converse API 스트리밍을 통한 AI 에이전트 웹 채팅 UI (React) 추가 (ADR-002 하이브리드 아키텍처)
- 마크다운 렌더링 (react-markdown + remark-gfm) 포함 Agent 페이지를 프론트엔드에 추가
- 브라우저 기반 AI 채팅을 위한 `/api/agent/chat` 엔드포인트 추가 (Bedrock Converse 스트리밍)
- 에이전트 도구 분리: `tools_jobs.py` (httpx → API 서버) + `tools_infra.py` (boto3 → AWS API)
- AI 기반 배치를 위한 `dispatch_mode` 설정 (`rule` | `agent`) 및 `agent_model` 구성 추가
- envsubst 기반 PV 템플릿으로 리전별 FSx Lustre 스토리지 추가 (us-east-1/2/us-west-2 3개 파일시스템)
- S3 presigned URL 생성을 위한 `s3_bucket` 설정을 pydantic-settings 구성에 추가
- 시나리오 3 데모에 실제 S3 업로드 및 FSx 자동 가져오기/내보내기 검증 추가 (애니메이션만이 아닌 실제 동작)
- 시나리오 4 데모 추가: AgentCore + Strands를 활용한 AI 에이전트 배치
- GPU Spot Lotto 메트릭을 위한 Grafana 대시보드 패널 추가
- 리전별 용량 추적을 위한 `REGION_CAPACITY` Prometheus 게이지 메트릭 추가
- ADR-001 (AgentCore + Strands AI 에이전트) 및 ADR-002 (하이브리드 에이전트 채팅 아키텍처) 추가
- 작업 기록 테이블에 검색 및 필터 기능 추가
- 작업 기록 테이블에 컬럼 헤더 정렬 기능 추가
- 데모 스크립트 시작 화면에 About 및 Steps 설명 추가
- shields.io 뱃지를 포함한 이중 언어 README.md (영어/한국어) 추가
- AI 보조 개발을 위한 CLAUDE.md 프로젝트 문서 계층 구조 추가 (12개 파일)
- 사전 커밋 시크릿 스캐닝 훅 추가 (AWS 키, API 토큰, 비밀번호)

### Changed

- AgentCore Gateway (MCP)를 에이전트 도구용 직접 httpx → API 서버 데이터 경로로 교체
- values-dev.yaml을 dry-run/mock 모드에서 live/live 모드로 전환
- ARCHITECTURE.md를 실제 구현에 맞게 업데이트 (20개 엔드포인트, 에이전트 채팅, Gateway 제거)
- 관리자 페이지 확장: AdminDashboard, AdminJobs, AdminRegions

### Fixed

- upload.py의 presigned URL 버킷 참조 수정 (`hasattr`가 항상 False를 반환하여 잘못된 버킷으로 폴백)
- 시나리오 3 STEP 3의 JSON 파싱 오류 수정 (연결된 JSON 블롭이 `json.decoder.JSONDecodeError` 유발)
- 데모 스크립트의 `set -euo pipefail` 안전성 수정 (`aws s3 ls`가 파일 미발견 시 non-zero 반환)
- 시나리오 3 데모에서 submit 응답 파싱 대신 admin 엔드포인트 폴링으로 작업 ID 검색 수정
- ARM-to-AMD64 크로스 컴파일을 위한 전용 Dockerfile.prod로 프론트엔드 Docker 빌드 수정
- harness 평가에서 식별된 보안 critical 4건 수정

### Removed

- `src/agent/tools.py` 삭제 (tools_jobs.py + tools_infra.py로 대체)
- `src/tests/unit/test_agent_tools.py` 삭제 (삭제된 tools.py의 테스트)
- 아키텍처, 에이전트 코드, 문서에서 AgentCore Gateway 참조 제거

## [0.1.0] - 2026-04-04

### Added

- us-east-1, us-east-2, us-west-2 3개 리전의 GPU Spot 가격 60초 주기 실시간 모니터링 추가
- 용량 인식 폴백을 포함한 최저가 리전 자동 작업 배치 추가
- REST API를 통한 작업 수명주기 관리 추가 (제출, 상태 조회, 취소, 재시도)
- SSE 실시간 작업 상태 스트리밍 엔드포인트 추가
- 체크포인트 보존을 포함한 Spot 인터럽션 감지 및 자동 재스케줄링 추가
- 작업 관리, 리전 용량 제어, 시스템 통계를 포함한 관리자 대시보드 추가
- React 18, Vite, shadcn/ui 기반 이중 언어 웹 UI (한국어/영어) 추가
- 자주 사용하는 설정 저장 및 재사용을 위한 작업 템플릿 추가
- API 프록시 없이 학습 데이터 및 모델 파일을 위한 S3 Presigned 업로드 추가
- 역할 기반 접근 제어(사용자/관리자)를 포함한 Cognito JWT 인증 추가
- Grafana 대시보드 및 알림을 위한 Prometheus 메트릭 엔드포인트 추가
- 서울 S3 허브와 Spot 리전별 FSx Lustre 자동 동기화 Hub-and-Spoke 스토리지 아키텍처 추가
- 온디맨드 노드 프로비저닝을 위한 Karpenter GPU Spot NodePool (g5, g6, g6e) 추가
- 개발/운영 환경별 값 오버라이드를 포함한 EKS 배포용 Helm 3 차트 추가
- 13개 모듈 Terraform IaC 추가 (VPC, EKS, Karpenter, ElastiCache, Cognito, ALB, CloudFront+WAF, ECR, FSx, S3, Pod Identity, GitHub OIDC, Monitoring)
- Docker 멀티스테이지 빌드 및 로컬 개발용 docker-compose 추가
- 3개 시나리오 인터랙티브 데모 스크립트 추가 (비용 최적화 배치, Spot 복구, 전체 수명주기)
- docker-compose 스택 검증을 위한 E2E 스모크 테스트 스크립트 추가

[Unreleased]: https://github.com/whchoi98/spot-gpu-lotto/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/whchoi98/spot-gpu-lotto/releases/tag/v0.1.0
