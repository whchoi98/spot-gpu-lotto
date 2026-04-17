# Tech Stack

## Backend (Python 3.11)
| Package | Purpose |
|---------|---------|
| FastAPI + Uvicorn | Async REST API server |
| redis[hiredis] | Async Redis client (prices, queue, jobs) |
| boto3 / aioboto3 | EC2 Spot API, S3 presigned URLs, Bedrock Converse |
| kubernetes | Pod creation in remote EKS clusters |
| pydantic v2 | Request/response validation |
| pydantic-settings | Environment variable config (cached via `@lru_cache`) |
| structlog | Structured JSON logging |
| prometheus-client | Metrics export |
| sse-starlette | Server-Sent Events streaming |
| httpx | HTTP client for agent→API calls |
| strands-agents | AI agent framework (AgentCore Runtime) |

## Frontend (TypeScript)
| Package | Purpose |
|---------|---------|
| React 18 | UI framework |
| Vite | Build tool / dev server |
| shadcn/ui | Component library (Radix + Tailwind) |
| TanStack Query | Server state management |
| react-i18next | Internationalization (ko/en) |
| react-markdown + remark-gfm | Agent chat markdown rendering |
| axios | HTTP client |
| react-router-dom v6 | Client-side routing |
| Lucide React | Icon library |
| i18next | Internationalization core |

## Infrastructure
| Tool | Purpose |
|------|---------|
| Terraform 1.x | IaC (13 modules) |
| Helm 3 | Kubernetes package management |
| Karpenter | GPU Spot node auto-provisioning |
| FSx Lustre | High-performance filesystem (S3 auto-import/export) |
| ElastiCache Redis 7 | In-memory data store (TLS enabled) |
| CloudFront + ALB | CDN + load balancing (IP target type) |
| Cognito | JWT authentication |
| ECR | Container image registry (immutable tags) |
| Grafana + Prometheus | Monitoring dashboards (Helm-provisioned) |
| AgentCore Runtime | Serverless Strands agent hosting (us-east-1) |
| AWS LB Controller | TargetGroupBinding for Pod IP auto-sync to ALB |
| EKS Pod Identity | IAM role binding for service accounts |

## Testing
| Tool | Purpose |
|------|---------|
| pytest + pytest-asyncio | Test runner (asyncio_mode=auto) |
| fakeredis | In-memory Redis mock (unit tests) |
| testcontainers[redis] | Real Redis in Docker (integration) |
| ruff | Python linter (E, F, I, N, W rules) |
| mypy | Python type checker (strict mode) |
