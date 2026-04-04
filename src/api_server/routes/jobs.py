"""Job submission, status, cancellation, and SSE streaming."""
from __future__ import annotations

import asyncio
import json

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sse_starlette.sse import EventSourceResponse

from api_server.auth import CurrentUser, get_current_user
from common.models import JobRecord, JobRequest, JobStatus
from common.redis_client import get_redis

router = APIRouter(prefix="/api", tags=["jobs"])


@router.post("/jobs")
async def submit_job(
    req: JobRequest,
    user: CurrentUser = Depends(get_current_user),
):
    """Submit a GPU job to the queue. Returns job_id immediately."""
    r = await get_redis()
    job_data = req.model_dump()
    job_data["user_id"] = user.user_id
    await r.lpush("gpu:job:queue", json.dumps(job_data))
    return {"status": "queued", "message": "Job submitted to queue"}


@router.get("/jobs/{job_id}")
async def get_job(
    job_id: str,
    user: CurrentUser = Depends(get_current_user),
):
    """Get job status."""
    r = await get_redis()
    data = await r.hgetall(f"gpu:jobs:{job_id}")
    if not data:
        raise HTTPException(status_code=404, detail="Job not found")

    job = JobRecord.from_redis(data)
    # Non-admin users can only see their own jobs
    if not user.is_admin and job.user_id != user.user_id:
        raise HTTPException(status_code=403, detail="Access denied")

    return job.model_dump()


@router.delete("/jobs/{job_id}")
async def cancel_job(
    job_id: str,
    user: CurrentUser = Depends(get_current_user),
):
    """Cancel a running job."""
    r = await get_redis()
    data = await r.hgetall(f"gpu:jobs:{job_id}")
    if not data:
        raise HTTPException(status_code=404, detail="Job not found")

    job = JobRecord.from_redis(data)
    if not user.is_admin and job.user_id != user.user_id:
        raise HTTPException(status_code=403, detail="Access denied")

    if job.status not in (JobStatus.RUNNING, JobStatus.QUEUED):
        raise HTTPException(status_code=400, detail=f"Cannot cancel job in {job.status} state")

    await r.hset(f"gpu:jobs:{job_id}", "status", JobStatus.CANCELLING)
    return {"status": "cancelling", "job_id": job_id}


class WebhookSettings(BaseModel):
    webhook_url: str


@router.put("/settings/webhook")
async def set_webhook(
    body: WebhookSettings,
    user: CurrentUser = Depends(get_current_user),
):
    """Save user's default webhook URL."""
    r = await get_redis()
    await r.set(f"gpu:user:{user.user_id}:webhook", body.webhook_url)
    return {"status": "saved", "webhook_url": body.webhook_url}


@router.get("/jobs/{job_id}/stream")
async def stream_job_status(
    job_id: str,
    user: CurrentUser = Depends(get_current_user),
):
    """SSE stream for real-time job status updates."""
    r = await get_redis()

    async def event_generator():
        pubsub = r.pubsub()
        await pubsub.subscribe(f"gpu:jobs:{job_id}:status")
        try:
            while True:
                msg = await pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
                if msg and msg["type"] == "message":
                    yield {"event": "status", "data": msg["data"]}
                    data = json.loads(msg["data"])
                    if data.get("status") in ("succeeded", "failed", "cancelled"):
                        break
                await asyncio.sleep(0.1)
        finally:
            await pubsub.unsubscribe()
            await pubsub.aclose()

    return EventSourceResponse(event_generator())
