# Runbook: Spot Instance Failover Recovery

## Overview
Procedure for responding to GPU Spot instance interruptions (evictions) and
ensuring in-flight training/inference jobs are recovered or retried across
alternate regions.

## When to Use
- AWS sends a Spot interruption notice (2-minute warning)
- GPU job pods enter `Failed` or `Unknown` state unexpectedly
- A region reports 0 capacity for extended period
- Karpenter fails to provision replacement Spot nodes
- Grafana alert fires for `JOBS_FAILED` spike or `REGION_CAPACITY` drop to 0

## Prerequisites
- `kubectl` configured for all 4 clusters (Seoul, us-east-1, us-east-2, us-west-2)
- `aws` CLI with appropriate IAM permissions
- Access to Grafana dashboard (grafana.internal or CloudFront URL)
- Access to Redis (via `kubectl exec` on api-server pod or `redis-cli`)

## Procedure

### 1. Assess the Situation

Check which regions have capacity issues:
```bash
# Check Spot price + capacity via API
curl -s https://d370iz4ydsallw.cloudfront.net/api/prices | python3 -c "
import sys, json
for p in json.load(sys.stdin):
    print(f\"{p['region']:14} {p['instance_type']:14} \${p['price']:.4f}  cap={p.get('capacity','?')}\")
"

# Check active jobs and queue depth
curl -s https://d370iz4ydsallw.cloudfront.net/api/admin/stats | python3 -m json.tool
```

Check nodes per region:
```bash
for CTX in gpu-lotto-dev-seoul gpu-lotto-dev-use1 gpu-lotto-dev-use2 gpu-lotto-dev-usw2; do
  echo "=== $CTX ==="
  kubectl get nodes --context $CTX -o wide 2>/dev/null || echo "  (unreachable)"
done
```

### 2. Identify Affected Jobs

List jobs in failed/running state that may have been interrupted:
```bash
# Get active jobs from Redis
kubectl exec -n gpu-lotto deploy/gpu-lotto-api-server -- python3 -c "
import asyncio, redis.asyncio as aioredis, json
async def main():
    r = aioredis.from_url('$REDIS_URL', decode_responses=True)
    ids = await r.smembers('gpu:active_jobs')
    for jid in ids:
        data = await r.hgetall(f'gpu:jobs:{jid}')
        print(f\"{jid[:12]}  status={data.get('status','?'):12}  region={data.get('region','?'):14}  retry={data.get('retry_count','0')}\")
asyncio.run(main())
"
```

Check for pods in non-Running state in GPU job namespaces:
```bash
for REGION in us-east-1 us-east-2 us-west-2; do
  SHORT=$(echo $REGION | sed 's/us-east-1/use1/;s/us-east-2/use2/;s/us-west-2/usw2/')
  echo "=== $REGION ==="
  kubectl get pods -n gpu-jobs --context gpu-lotto-dev-$SHORT \
    --field-selector 'status.phase!=Running' 2>/dev/null || echo "  (no issues)"
done
```

### 3. Manual Retry (if Reaper Not Working)

The dispatcher's reaper automatically detects failed pods and retries jobs
(up to `max_retries=2`) in alternate regions. If the reaper is not functioning:

```bash
# Check dispatcher logs for reaper activity
kubectl logs -n gpu-lotto deploy/gpu-lotto-dispatcher --tail=50 | grep -E "reap|retry"

# If dispatcher is down, restart it
kubectl rollout restart deploy/gpu-lotto-dispatcher -n gpu-lotto
```

To manually requeue a specific failed job (emergency only):
```bash
kubectl exec -n gpu-lotto deploy/gpu-lotto-api-server -- python3 -c "
import asyncio, redis.asyncio as aioredis, json
async def main():
    r = aioredis.from_url('$REDIS_URL', decode_responses=True)
    job = {'instance_type': 'g6.xlarge', 'image': '<ORIGINAL_IMAGE>', 'command': ['<ORIGINAL_CMD>']}
    await r.lpush('gpu:job:queue', json.dumps(job))
    print('Job requeued')
asyncio.run(main())
"
```

### 4. Capacity Recovery

If a region has 0 capacity due to evictions but pods have been cleaned up:
```bash
# Check current capacity values
for REGION in us-east-1 us-east-2 us-west-2; do
  kubectl exec -n gpu-lotto deploy/gpu-lotto-api-server -- python3 -c "
import asyncio, redis.asyncio as aioredis
async def main():
    r = aioredis.from_url('$REDIS_URL', decode_responses=True)
    cap = await r.get('gpu:capacity:$REGION')
    active = await r.smembers('gpu:active_jobs')
    region_jobs = 0
    for jid in active:
        data = await r.hgetall(f'gpu:jobs:{jid}')
        if data.get('region') == '$REGION' and data.get('status') == 'running':
            region_jobs += 1
    print(f'$REGION: capacity={cap}, running_jobs={region_jobs}')
asyncio.run(main())
"
done
```

Reset capacity if it's out of sync (capacity + running jobs should = capacity_per_region):
```bash
# Reset to configured max (16 per region) minus actual running jobs
kubectl exec -n gpu-lotto deploy/gpu-lotto-api-server -- python3 -c "
import asyncio, redis.asyncio as aioredis
async def main():
    r = aioredis.from_url('$REDIS_URL', decode_responses=True)
    await r.set('gpu:capacity:<REGION>', '<CORRECT_VALUE>')
    print('Capacity reset')
asyncio.run(main())
"
```

### 5. Verify Karpenter Recovery

Karpenter should automatically provision new Spot nodes when jobs are requeued:
```bash
# Check Karpenter NodePool status
kubectl get nodepools -A --context gpu-lotto-dev-use1
kubectl get nodeclaims -A --context gpu-lotto-dev-use1

# Check Karpenter logs for provisioning activity
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=30 --context gpu-lotto-dev-use1
```

## Verification
- [ ] All affected jobs are in `running`, `succeeded`, or `queued` (retry) state
- [ ] `REGION_CAPACITY` gauge shows non-zero values for healthy regions
- [ ] `QUEUE_DEPTH` gauge is 0 (no backlog)
- [ ] Karpenter NodeClaims are in `Launched` or `Ready` state
- [ ] No pods stuck in `Pending` or `Unknown` in gpu-jobs namespace

## Rollback
If manual capacity reset causes over-provisioning:
```bash
# Set capacity back to 0 and let init_capacity handle it on next dispatcher restart
kubectl rollout restart deploy/gpu-lotto-dispatcher -n gpu-lotto
```

## Notes
- The system supports automatic failover: reaper detects failed pods, retries in alternate regions
- `exclude_regions` in retry ensures the failing region is skipped on next attempt
- Max retries = 2 (configurable via `MAX_RETRIES` env var)
- Checkpoint-enabled jobs save progress to FSx Lustre, so resumed jobs don't restart from scratch
- Last verified: 2026-04-14
