# Steering — Code Style & Behavior

## Python
- Async-first: all Redis/HTTP operations use `await`
- Pydantic v2 models with `str | None = None` (not `Optional[str]`)
- Config via pydantic-settings (`Settings` class, env vars)
- structlog for JSON logging
- Line length: 100, target: py311
- Linter: ruff (E, F, I, N, W rules)
- Type checker: mypy strict mode

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

## Git
- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- Branch naming: `feat/`, `fix/`, `docs/`, `refactor/`

## Testing
- `asyncio_mode = "auto"` — no `@pytest.mark.asyncio` needed
- `pythonpath = ["src"]` — imports: `from common.xxx import yyy`
- Unit tests: fakeredis (no external deps)
- Integration tests: testcontainers[redis]

## Infrastructure
- Docker: always `--platform linux/amd64` (ARM dev host → AMD64 target)
- ECR tags: immutable, increment on each push (v9, v10, ...)
- Helm: `values-dev.yaml` for dev, `values-prod.yaml` for prod
- Terraform: plan before apply, `terraform destroy` is forbidden
- ALB: IP target type — re-register Pod IP after restart
- FSx PV manifests: use `envsubst` for filesystem IDs (`${FSX_FILESYSTEM_ID}`, `${FSX_DNS_NAME}`, `${FSX_MOUNT_NAME}`)
- EKS cluster naming: `{cluster_prefix}-{region_short}` (e.g. `gpu-lotto-dev-use1`)

## Security
- No hardcoded secrets in source code
- Cognito JWT auth in prod, disabled in dev (`AUTH_ENABLED=false`)
- Pre-commit hook scans for AWS keys, API keys, passwords
- `.env` files must be in `.gitignore`

## Response Language
- Respond in the same language the user uses (Korean or English)
- Code comments in English
