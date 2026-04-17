# Steering — Code Style & Behavior

## Python
- Async-first: all Redis/HTTP operations use `await`
- Pydantic v2 models with `str | None = None` (not `Optional[str]`)
- Config via pydantic-settings (`Settings` class, env vars), cached with `@lru_cache`
- structlog for JSON logging
- Line length: 100, target: py311
- Linter: ruff (E, F, I, N, W rules)
- Type checker: mypy strict mode
- All models use `str | None = None` for optional fields
- Use `dict.get("key") or default` (not `dict.get("key", default)`) to handle Redis None values

## TypeScript / React
- Strict mode enabled
- Path alias: `@/` → `src/`
- shadcn/ui components in `src/components/ui/` — do not modify directly
- TanStack Query for server state
- axios via `src/lib/api.ts` (base: `/api`)
- react-markdown + remark-gfm for agent chat rendering
- Types in `src/lib/types.ts` must match backend Pydantic models
- i18n: every user-facing string needs both `ko` and `en` in `src/lib/i18n.ts`

## Agent Code
- `tools_jobs.py`: httpx → API Server only (no direct Redis)
- `tools_infra.py`: boto3/kubernetes direct calls
- Chat endpoint (`routes/agent.py`): Bedrock Converse + Redis context injection
- Hybrid approval: actions proposed via `proposal` code blocks in LLM response
- System prompt duplicated in `routes/agent.py` and `src/agent/system_prompt.py` — keep in sync
- Model: `global.anthropic.claude-sonnet-4-6` (configurable via AGENT_MODEL)
- Agent responds in the same language as the user (Korean/English)

## API Server
- Pydantic model validation runs BEFORE FastAPI dependency injection (auth)
- Request body fields must be optional if overridden by middleware
- All Redis operations are async (`await r.xxx()`)
- `POST /api/jobs` returns no job_id — dispatcher generates it (UUID4)
- Auth: Cognito JWT in prod, hardcoded `dev-user/admin` when `AUTH_ENABLED=false`

## Dispatcher
- Always use `job.get("key") or default` for Redis hash fields
- `k8s_mode: dry-run` skips actual Pod creation (dev environment)
- `dispatch_mode: agent` logs warning and falls back to rule-based
- Pod builder uses `nodeSelector: gpu-lotto/pool: gpu-spot` (NOT `eks.amazonaws.com/instance-gpu-name`)
- Pod builder supports two storage modes: "fsx" (FSx Lustre PVCs) and "s3" (emptyDir fallback)

## Price Watcher
- Poll interval: `POLL_INTERVAL` env var (default 30s dev)
- Price mode: `live` (real EC2 API) or `mock` (static test data)
- Sorted set: ZADD with GT flag (atomic replace)

## Git
- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- Branch naming: `feat/`, `fix/`, `docs/`, `refactor/`

## Testing
- `asyncio_mode = "auto"` — no `@pytest.mark.asyncio` needed
- `pythonpath = ["src"]` — imports: `from common.xxx import yyy`
- Unit tests: fakeredis (no external deps)
- Integration tests: testcontainers[redis]

## Infrastructure
- Docker: always `--platform linux/arm64` (ARM dev host + ARM EKS Graviton nodes)
- ECR tags: immutable, increment on each push (v9, v10, ...)
- Helm: `values-dev.yaml` for dev, `values-prod.yaml` for prod
- Terraform: plan before apply, `terraform destroy` is forbidden
- ALB: IP target type — Pod IPs auto-synced via TargetGroupBinding + AWS LB Controller (Pod Identity)
- FSx PV manifests: use `envsubst` for filesystem IDs (`${FSX_FILESYSTEM_ID}`, `${FSX_DNS_NAME}`, `${FSX_MOUNT_NAME}`)
- EKS cluster naming: `{cluster_prefix}-{region_short}` (e.g. `gpu-lotto-dev-use1`)
- Karpenter NodePool targets Spot instances only (capacity type: spot)
- TargetGroupBinding uses `elbv2.k8s.aws/v1beta1` API (AWS LB Controller)

## Demos
- All scripts use ASCII-only characters (no Unicode — `tr` breaks multi-byte chars)
- `hr()` function uses loop, not `tr` for character repetition
- `center()` splits `local` assignment across two lines (`set -u` compatibility)
- Scripts call real endpoints: `$API/prices`, `$API/jobs`, `$API/admin/jobs`
- `POST /api/jobs` returns no job_id — must poll `GET /api/admin/jobs` to discover new job
- `GPU_LOTTO_URL` env var overrides default CloudFront URL

## Security
- No hardcoded secrets in source code
- Cognito JWT auth in prod, disabled in dev (`AUTH_ENABLED=false`)
- Pre-commit hook scans for AWS keys, API keys, passwords
- `.env` files must be in `.gitignore`

## Response Language
- Respond in the same language the user uses (Korean or English)
- Code comments in English
