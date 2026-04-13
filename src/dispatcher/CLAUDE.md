# Dispatcher Module

## Role
Consumes jobs from Redis queue (BRPOP loop), selects the cheapest region,
creates GPU Pods via Kubernetes API, and records job state in Redis.

## Key Files
- `main.py` -- Entry point, starts queue processor and reaper
- `queue_processor.py` -- `process_queue()` BRPOP loop + `process_one_job()` dispatch logic
- `region_selector.py` -- `select_region()` reads sorted set, iterates cheapest-first
- `capacity.py` -- Atomic GPU capacity management with Redis transactions
- `pod_builder.py` -- `build_gpu_pod()` constructs V1Pod with volume mounts (FSx/S3)
- `reaper.py` -- Job reaper: handles retry, timeout, and cancel for stale/failed jobs
- `notifier.py` -- `notify_job_status()` publishes to Redis Pub/Sub + webhook

## Job Lifecycle
1. BRPOP from `gpu:job:queue`
2. `select_region()` finds cheapest region with capacity
3. If no capacity: retry up to `max_retries`, then fail
4. `build_gpu_pod()` with mounts: /data/models (RO), /data/results (RW), /data/checkpoints
5. In `live` mode: `k8s.create_namespaced_pod()`; in `dry-run`: log only
6. Record job in `gpu:jobs:{job_id}` hash + add to `gpu:active_jobs` set
7. Notify via Pub/Sub + webhook

## Rules
- `job_id` is generated here (UUID4), NOT by the API server
- Always use `job.get("key") or default` (not `job.get("key", default)`) to handle None values
- `k8s_mode: dry-run` skips actual Pod creation (dev environment)
- `dispatch_mode: agent` logs a warning and falls back to rule-based dispatch (agent runs on AgentCore Runtime, not in dispatcher)
- Pod builder supports two storage modes: "fsx" (FSx Lustre PVCs) and "s3" (emptyDir fallback)
- Pod builder uses `nodeSelector: gpu-lotto/pool: gpu-spot` (NOT `eks.amazonaws.com/instance-gpu-name`)
  because EKS Auto Mode cannot match GPU name labels with Spot offerings at scheduling time
