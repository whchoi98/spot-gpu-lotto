"""Process GPU job queue — BRPOP loop with dispatch logic."""
import json
import time
import uuid

import redis.asyncio as aioredis

from common.config import get_settings
from common.k8s_client import get_k8s_client, invalidate_client
from common.logging import get_logger
from common.metrics import JOBS_DISPATCHED, JOBS_FAILED, JOBS_RETRIED, QUEUE_DEPTH
from common.models import JobStatus
from dispatcher.notifier import notify_job_status
from dispatcher.pod_builder import build_gpu_pod
from dispatcher.region_selector import select_region

log = get_logger("queue_processor")


async def process_one_job(r: aioredis.Redis, job_json: str) -> dict:
    """Process a single job from the queue."""
    settings = get_settings()
    job = json.loads(job_json)
    job_id = str(uuid.uuid4())
    instance_type = job.get("instance_type", "g6.xlarge")

    # Select cheapest region with capacity
    result = await select_region(r, instance_type)
    if result is None:
        # No capacity — check retry
        retry_count = job.get("_retry_count", 0)
        if retry_count < settings.max_retries:
            job["_retry_count"] = retry_count + 1
            await r.lpush("gpu:job:queue", json.dumps(job))
            JOBS_RETRIED.inc()
            log.warning("no_capacity_requeue", job_id=job_id, retry=retry_count + 1)
            return {"job_id": job_id, "status": "requeued"}
        else:
            JOBS_FAILED.labels(reason="no_capacity").inc()
            log.error("no_capacity_max_retries", job_id=job_id)
            return {"job_id": job_id, "status": "failed", "error": "no_capacity"}

    region, price = result

    # Create Pod
    if settings.k8s_mode == "live":
        k8s = get_k8s_client(region)
        pod = build_gpu_pod(job_id, job)
        try:
            k8s.create_namespaced_pod(namespace="gpu-jobs", body=pod)
        except Exception as e:
            if "Unauthorized" in str(e) or "401" in str(e):
                invalidate_client(region)
            raise
    else:
        pod = build_gpu_pod(job_id, job)
        log.info("dry_run_pod_created", job_id=job_id, region=region)

    # Record job state
    now = str(int(time.time()))
    await r.hset(f"gpu:jobs:{job_id}", mapping={
        "job_id": job_id,
        "user_id": job.get("user_id") or "unknown",
        "region": region,
        "status": JobStatus.RUNNING,
        "pod_name": pod.metadata.name,
        "instance_type": instance_type,
        "created_at": now,
        "retry_count": "0",
        "checkpoint_enabled": str(job.get("checkpoint_enabled", False)).lower(),
        "webhook_url": job.get("webhook_url") or "",
    })
    await r.sadd("gpu:active_jobs", job_id)

    # Notify
    await notify_job_status(r, job_id, "running", region=region, spot_price=price)

    JOBS_DISPATCHED.labels(region=region).inc()
    log.info("job_dispatched", job_id=job_id, region=region, price=price)
    return {"job_id": job_id, "region": region, "spot_price": price, "status": "running"}


async def process_queue(r: aioredis.Redis) -> None:
    """Main BRPOP loop — runs forever."""
    settings = get_settings()
    log.info("queue_processor_started", dispatch_mode=settings.dispatch_mode)
    if settings.dispatch_mode == "agent":
        log.info("agent_mode_active", msg="Jobs are handled by AgentCore agent. Queue processor idle.")
    while True:
        queue_len = await r.llen("gpu:job:queue")
        QUEUE_DEPTH.set(queue_len)
        item = await r.brpop("gpu:job:queue", timeout=5)
        if item:
            _, job_json = item
            try:
                result = await process_one_job(r, job_json)
                log.info("job_processed", result=result)
            except Exception as e:
                log.error("job_processing_error", error=str(e))
