---
description: Build and deploy GPU Spot Lotto following project runbooks
allowed-tools: Read, Bash(docker buildx:*), Bash(helm:*), Bash(kubectl:*), Bash(npm run build:*), Bash(terraform plan:*), Glob
---

# Deploy

Build and deploy GPU Spot Lotto.

## Step 1: Pre-Deploy Checks

1. Verify working tree is clean: `git status`
2. Verify current branch (warn if not main/master)
3. Run lint/type checks: `ruff check src/` and `cd frontend && npx tsc --noEmit`
4. Check if a deployment runbook exists: `ls docs/runbooks/deploy-*.md`

## Step 2: Build

### Backend (from project root)
```bash
docker buildx build --builder amd64builder --platform linux/amd64 \
  -t $ECR_REGISTRY/gpu-lotto/<service>:<tag> --push .
```

### Frontend (from frontend/)
```bash
cd frontend
docker buildx build --builder amd64builder --platform linux/amd64 \
  -f Dockerfile.prod -t $ECR_REGISTRY/gpu-lotto/frontend:<tag> --push .
```

## Step 3: Deploy via Helm

```bash
helm upgrade gpu-lotto helm/gpu-lotto -n gpu-lotto \
  -f helm/gpu-lotto/values-dev.yaml \
  --set global.image.registry=$ECR_REGISTRY \
  --set config.redisUrl=$REDIS_URL
```

## Step 4: Verify

```bash
kubectl rollout status deploy/gpu-lotto-api-server -n gpu-lotto
kubectl rollout status deploy/gpu-lotto-dispatcher -n gpu-lotto
kubectl rollout status deploy/gpu-lotto-frontend -n gpu-lotto
```

## Error Recovery

### If Helm upgrade fails
```bash
helm rollback gpu-lotto -n gpu-lotto
```

### If pods crash after deploy
```bash
kubectl logs deploy/gpu-lotto-api-server -n gpu-lotto --tail=50
kubectl describe pod -l app.kubernetes.io/name=api-server -n gpu-lotto
```

### If ALB target health fails
Pod IP changed after restart — re-register targets or wait for ALB health check.
