# Rules

## Forbidden Actions
- `rm -rf` or `rm -r` on any directory
- `git push --force`, `git reset --hard`, `git clean -f`
- `chmod 777` on any file
- `curl | bash` or `wget | bash` (piped execution)
- `eval` with untrusted input
- `terraform destroy` in any environment
- Hardcoding AWS credentials, API keys, or passwords in source

## Required Validations
- Run `ruff check src/` before committing Python changes
- Run `mypy src/` before committing Python changes
- Run `npx tsc --noEmit` before committing TypeScript changes
- Verify `pytest -v` passes before merging

## Code Change Rules
- New module under `src/` must have corresponding documentation
- API endpoint changes must update `docs/api-reference.md`
- Architecture decisions must be recorded as ADR in `docs/decisions/`
- Both `ko` and `en` i18n translations required for UI text
- Redis key structure changes must be documented

## Deployment Rules
- Verify clean working tree before deploy
- Always increment ECR image tag (immutable tags)
- Use `helm upgrade` (not `helm install`) for updates
- Run health checks after deployment (`/healthz`, `/readyz`)
- ConfigMap changes require `kubectl rollout restart`

## Testing Rules
- Unit tests use fakeredis — no external service dependencies
- Integration tests use testcontainers — Docker required
- `asyncio_mode = "auto"` — do not add `@pytest.mark.asyncio`
- Test imports use `from common.xxx import yyy` (pythonpath = ["src"])
