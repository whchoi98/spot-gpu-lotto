# Runbook: Redis (ElastiCache) Recovery

## Overview
Procedure for diagnosing and recovering from Redis connectivity failures or
data loss in the ElastiCache Redis cluster that serves as the central data store
for GPU Spot Lotto (prices, job queue, job state, capacity counters).

## When to Use
- API server `/readyz` endpoint returns unhealthy (Redis ping fails)
- Grafana alert fires for Redis connection errors
- Jobs are not being dispatched (queue not draining)
- Spot prices show stale data (not updating)
- ElastiCache console shows `modifying`, `snapshotting`, or `failed` status

## Prerequisites
- AWS Console access to ElastiCache in ap-northeast-2 (Seoul)
- `kubectl` configured for Seoul cluster (`gpu-lotto-dev-seoul`)
- `aws` CLI with ElastiCache and EC2 permissions
- Redis endpoint: `master.<cluster>.cache.amazonaws.com:6379`

## Procedure

### 1. Diagnose Connectivity

Check API server health (Redis ping is part of readiness check):
```bash
curl -s https://d370iz4ydsallw.cloudfront.net/readyz | python3 -m json.tool
```

Check directly from the API server pod:
```bash
kubectl exec -n gpu-lotto deploy/gpu-lotto-api-server -- python3 -c "
import asyncio, redis.asyncio as aioredis
async def main():
    r = aioredis.from_url('$REDIS_URL', decode_responses=True)
    try:
        pong = await r.ping()
        print(f'PING: {pong}')
        info = await r.info('server')
        print(f'Redis version: {info[\"redis_version\"]}')
        print(f'Connected clients: {(await r.info(\"clients\"))[\"connected_clients\"]}')
    except Exception as e:
        print(f'ERROR: {e}')
asyncio.run(main())
"
```

### 2. Check ElastiCache Status

```bash
# Replication group status
aws elasticache describe-replication-groups \
  --region ap-northeast-2 \
  --query 'ReplicationGroups[].{Id:ReplicationGroupId, Status:Status, Endpoint:NodeGroups[0].PrimaryEndpoint.Address}' \
  --output table

# Node health
aws elasticache describe-cache-clusters \
  --region ap-northeast-2 \
  --show-cache-node-info \
  --query 'CacheClusters[].{Id:CacheClusterId, Status:CacheClusterStatus, Engine:EngineVersion, NodeType:CacheNodeType}' \
  --output table
```

### 3. Check Network Path

Redis runs in a private subnet. Verify security group allows traffic from EKS pods:
```bash
# Get the ElastiCache security group
RG_ID=$(aws elasticache describe-replication-groups --region ap-northeast-2 \
  --query 'ReplicationGroups[0].MemberClusters[0]' --output text)
SG_ID=$(aws elasticache describe-cache-clusters --cache-cluster-id $RG_ID \
  --region ap-northeast-2 \
  --query 'CacheClusters[0].SecurityGroups[0].SecurityGroupId' --output text)

# Check inbound rules (should allow port 6379 from EKS CIDR)
aws ec2 describe-security-group-rules --region ap-northeast-2 \
  --filters "Name=group-id,Values=$SG_ID" \
  --query 'SecurityGroupRules[?IsEgress==`false`].{Port:FromPort, CIDR:CidrIpv4, SourceSG:ReferencedGroupInfo.GroupId}' \
  --output table
```

### 4. Recovery Scenarios

#### 4a. Transient Connection Error
Services auto-reconnect. Just restart the affected pods:
```bash
kubectl rollout restart deploy/gpu-lotto-api-server deploy/gpu-lotto-dispatcher -n gpu-lotto
kubectl rollout status deploy/gpu-lotto-api-server deploy/gpu-lotto-dispatcher -n gpu-lotto
```

#### 4b. ElastiCache Node Failure (Automatic Failover)
ElastiCache Multi-AZ automatically promotes a replica. Confirm:
```bash
aws elasticache describe-events \
  --region ap-northeast-2 \
  --source-type replication-group \
  --duration 60 \
  --query 'Events[].{Date:Date, Message:Message}' \
  --output table
```
After failover, the DNS endpoint resolves to the new primary. Restart services
to re-establish connections:
```bash
kubectl rollout restart deploy/gpu-lotto-api-server deploy/gpu-lotto-dispatcher \
  deploy/gpu-lotto-price-watcher -n gpu-lotto
```

#### 4c. Data Loss (Redis Flushed or Snapshot Restore)
If Redis data is lost, the following keys must be repopulated:

| Key Pattern | Source | Recovery Method |
|---|---|---|
| `gpu:spot:prices` | EC2 Spot Price API | Price watcher repopulates within `poll_interval` (30s dev, 60s prod) |
| `gpu:job:queue` | Lost | Cannot recover queued jobs — users must resubmit |
| `gpu:jobs:{id}` | Lost | Active jobs become orphaned pods — reaper will clean up |
| `gpu:active_jobs` | Lost | Rebuild from running pods (see below) |
| `gpu:capacity:{region}` | Config | Re-initialized on dispatcher startup via `init_capacity()` |

Rebuild `gpu:active_jobs` from running pods (emergency):
```bash
kubectl exec -n gpu-lotto deploy/gpu-lotto-api-server -- python3 -c "
import asyncio, redis.asyncio as aioredis
async def main():
    r = aioredis.from_url('$REDIS_URL', decode_responses=True)
    # Re-init capacity
    for region in ['us-east-1', 'us-east-2', 'us-west-2']:
        exists = await r.exists(f'gpu:capacity:{region}')
        if not exists:
            await r.set(f'gpu:capacity:{region}', '16')
            print(f'Capacity initialized: {region}=16')
    print('Done. Price watcher will repopulate prices within 30s.')
asyncio.run(main())
"
```

Then restart all services to re-establish state:
```bash
kubectl rollout restart deploy/gpu-lotto-api-server deploy/gpu-lotto-dispatcher \
  deploy/gpu-lotto-price-watcher -n gpu-lotto
```

### 5. Monitor Recovery

```bash
# Watch readiness recover
kubectl get pods -n gpu-lotto -w

# Confirm prices are flowing
curl -s https://d370iz4ydsallw.cloudfront.net/api/prices | python3 -c "
import sys, json; d=json.load(sys.stdin); print(f'Prices: {len(d)} entries')
"

# Confirm queue is draining
curl -s https://d370iz4ydsallw.cloudfront.net/api/admin/stats | python3 -m json.tool
```

## Verification
- [ ] `/readyz` returns `{"status": "healthy"}`
- [ ] `/api/prices` returns non-empty price list with recent `updated_at`
- [ ] `QUEUE_DEPTH` gauge is stable (not growing)
- [ ] All pods in `gpu-lotto` namespace are `Running` and `Ready`
- [ ] ElastiCache status is `available` in AWS Console

## Rollback
If ElastiCache recovery fails completely:
- Restore from the latest automatic snapshot via AWS Console
- Or create a new cluster from snapshot:
  ```bash
  aws elasticache create-replication-group \
    --replication-group-id gpu-lotto-dev-restored \
    --replication-group-description "Restored from snapshot" \
    --snapshot-name <latest-snapshot-name> \
    --region ap-northeast-2
  ```
- Update `REDIS_URL` in Helm values and redeploy

## Notes
- ElastiCache uses TLS in transit (`rediss://` URL scheme) and encryption at rest
- Connection pool size: 20 (configured in `redis_client.py`)
- Price watcher polls every 30s (dev) / 60s (prod), so prices recover quickly
- Capacity counters are re-initialized on dispatcher startup if missing
- Job queue data is ephemeral — design assumes jobs can be resubmitted
- Last verified: 2026-04-14
