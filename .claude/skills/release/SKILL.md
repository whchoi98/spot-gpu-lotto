# Release Skill

Automate the release process with validation checks.

## Procedure

### 1. Pre-release Checks
- Verify working tree is clean: `git status`
- Verify all tests pass: `pytest -v`
- Check frontend builds: `cd frontend && npm run build`
- Lint: `ruff check src/ && mypy src/`

### 2. Determine Version
- Review changes since last tag: `git log $(git describe --tags --abbrev=0)..HEAD --oneline`
- Apply semver: MAJOR (breaking API), MINOR (new features), PATCH (bug fixes)

### 3. Build & Push Images
- Backend: `docker buildx build --platform linux/amd64 -t <ecr>/<service>:<tag> --push .`
- Frontend: `cd frontend && npm run build && docker buildx build -f Dockerfile.prod --platform linux/amd64 -t <ecr>/frontend:<tag> --push .`
- Update `helm/gpu-lotto/values-dev.yaml` with new tags

### 4. Deploy
- `helm upgrade gpu-lotto helm/gpu-lotto -n gpu-lotto -f helm/gpu-lotto/values-dev.yaml`
- `kubectl rollout restart` affected deployments
- Re-register Pod IPs in ALB target groups

### 5. Verify
- Check pod status: `kubectl get pods -n gpu-lotto`
- Health check: `curl -s https://d370iz4ydsallw.cloudfront.net/api/health`
- Verify frontend: `curl -s https://d370iz4ydsallw.cloudfront.net/ | grep index-`
