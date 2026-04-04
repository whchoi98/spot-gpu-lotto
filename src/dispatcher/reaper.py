"""Reap completed/failed/timed-out GPU jobs and manage retries."""
from __future__ import annotations

import time

import redis.asyncio as aioredis

from common.config import get_settings
from common.logging import get_logger
from common.models import JobRecord, JobStatus
from dispatcher.capacity import release_capacity
from dispatcher.notifier import notify_job_status

log = get_logger("reaper")


async def reap_job(
    r: aioredis.Redis,
    job_id: str,
    get_pod_phase: callable,
    delete_pod: callable,
    requeue_fn: callable | None = None,
) -> str | None:
    """Check a single job and handle its state. Returns new status or None if unchanged.

    get_pod_phase(region, pod_name) -> str | None: returns pod phase or None on error
    delete_pod(region, pod_name) -> bool: delete the pod
    requeue_fn(job, exclude_region) -> None: re-enqueue job for retry
    """
    settings = get_settings()
    data = await r.hgetall(f"gpu:jobs:{job_id}")
    if not data:
        await r.srem("gpu:active_jobs", job_id)
        return None

    job = JobRecord.from_redis(data)
    now = int(time.time())

    # Handle cancelling
    if job.status == JobStatus.CANCELLING:
        delete_pod(job.region, job.pod_name)
        await _finish_job(r, job, JobStatus.CANCELLED)
        return "cancelled"

    # Timeout check
    if now - job.created_at > settings.job_timeout:
        delete_pod(job.region, job.pod_name)
        await _finish_job(r, job, JobStatus.FAILED, error_reason="timeout")
        return "failed"

    # Check pod phase
    phase = get_pod_phase(job.region, job.pod_name)
    if phase is None:
        return None  # Could not check, skip

    if phase == "Succeeded":
        delete_pod(job.region, job.pod_name)
        await _finish_job(r, job, JobStatus.SUCCEEDED)
        return "succeeded"

    if phase == "Failed":
        delete_pod(job.region, job.pod_name)
        if job.retry_count < settings.max_retries and requeue_fn:
            # Re-enqueue for retry in a different region
            await r.hset(f"gpu:jobs:{job_id}", "retry_count", str(job.retry_count + 1))
            await r.hset(f"gpu:jobs:{job_id}", "status", JobStatus.QUEUED)
            await notify_job_status(r, job_id, "queued", webhook_url=job.webhook_url,
                                    region=job.region, retry_count=job.retry_count + 1)
            requeue_fn(job, job.region)
            log.info("job_retry", job_id=job_id, retry=job.retry_count + 1, exclude=job.region)
            return "queued"
        else:
            await _finish_job(r, job, JobStatus.FAILED, error_reason="pod_failed")
            return "failed"

    return None  # Still running


async def _finish_job(
    r: aioredis.Redis,
    job: JobRecord,
    status: JobStatus,
    error_reason: str | None = None,
) -> None:
    """Finalize a job: update Redis, release capacity, notify."""
    now = str(int(time.time()))
    updates = {"status": status.value, "finished_at": now}
    if error_reason:
        updates["error_reason"] = error_reason

    await r.hset(f"gpu:jobs:{job.job_id}", mapping=updates)
    await r.srem("gpu:active_jobs", job.job_id)
    await release_capacity(r, job.region)
    await notify_job_status(
        r, job.job_id, status.value,
        webhook_url=job.webhook_url,
        region=job.region,
        error_reason=error_reason,
    )
    log.info("job_finished", job_id=job.job_id, status=status.value, region=job.region)
