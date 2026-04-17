# Rules

## Forbidden Actions
- `rm -rf` or `rm -r` on any directory
- `git push --force`, `git push --delete`, `git reset --hard`, `git clean -f`, `git filter-branch`
- `chmod 777` on any file
- `curl | bash`, `curl | sh`, `wget | bash`, `wget | sh` (piped execution)
- `eval` or `exec` with untrusted input
- `terraform destroy` in any environment
- `kubectl delete namespace` on any namespace
- Hardcoding AWS credentials, API keys, or passwords in source
- Deleting or force-removing files without explicit user confirmation

## Required Validations
- Run `ruff check src/` before committing Python changes
- Run `mypy src/` before committing Python changes
- Run `npx tsc --noEmit` before committing TypeScript changes
- Verify `pytest -v` passes before merging
- Pre-commit hook scans for secrets (AWS keys, API keys, passwords)

## Code Change Rules
- New module under `src/` must have corresponding entry in `.kiro/docs/modules.md`
- API endpoint changes must update `docs/api-reference.md`
- Architecture decisions must be recorded as ADR in `docs/decisions/`
- Both `ko` and `en` i18n translations required for UI text
- Redis key structure changes must be documented in AGENT.md
- Agent system prompt changes must be synced between `routes/agent.py` and `src/agent/system_prompt.py`
- Helm chart changes must update `.kiro/docs/modules.md` Helm section
- Infrastructure changes must update `.kiro/docs/architecture.md`

## Agent Rules
- `tools_jobs.py`: MUST use httpx → API Server, NEVER direct Redis
- `tools_infra.py`: direct boto3/kubernetes calls allowed
- Chat endpoint: always inject fresh Redis context into system prompt
- Hybrid approval: only propose actions when user explicitly requests execution
- `POST /api/jobs` returns no job_id — dispatcher generates UUID4

## Deployment Rules
- Verify clean working tree before deploy
- Always increment ECR image tag (immutable tags)
- Use `helm upgrade` (not `helm install`) for updates
- Run health checks after deployment (`/healthz`, `/readyz`)
- ConfigMap changes require `kubectl rollout restart`
- FSx PV manifests: use `envsubst` before `kubectl apply`
- Docker images: always `--platform linux/arm64` (ARM Graviton target)

## Testing Rules
- Unit tests use fakeredis — no external service dependencies
- Integration tests use testcontainers — Docker required
- `asyncio_mode = "auto"` — do not add `@pytest.mark.asyncio`
- Test imports use `from common.xxx import yyy` (pythonpath = ["src"])

## Terraform Rules
- State stored in S3 backend with DynamoDB locking
- All modules use variable inputs — no hardcoded values
- Always `terraform plan` before `terraform apply`
- `terraform destroy` is absolutely forbidden

## K8s Manifest Rules
- Karpenter NodePool targets Spot instances only (capacity type: spot)
- FSx Lustre PVs are per-region — must be created in each spot region's EKS cluster
- `fsx-lustre-pv.yaml` requires envsubst: `FSX_FILESYSTEM_ID`, `FSX_DNS_NAME`, `FSX_MOUNT_NAME`
- Pod builder uses `nodeSelector: gpu-lotto/pool: gpu-spot`
