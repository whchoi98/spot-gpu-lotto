"""Admin-only endpoints for system management."""
from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from api_server.auth import CurrentUser, require_admin
from common.config import get_settings
from common.models import JobStatus
from common.redis_client import get_redis

router = APIRouter(prefix="/api/admin", tags=["admin"])


@router.get("/jobs")
async def list_all_jobs(user: CurrentUser = Depends(require_admin)):
    r = await get_redis()
    active_ids = await r.smembers("gpu:active_jobs")
    jobs = []
    for job_id in active_ids:
        data = await r.hgetall(f"gpu:jobs:{job_id}")
        if data:
            jobs.append(data)
    return {"jobs": jobs, "count": len(jobs)}


@router.delete("/jobs/{job_id}")
async def force_cancel_job(
    job_id: str,
    user: CurrentUser = Depends(require_admin),
):
    r = await get_redis()
    data = await r.hgetall(f"gpu:jobs:{job_id}")
    if not data:
        raise HTTPException(status_code=404, detail="Job not found")
    await r.hset(f"gpu:jobs:{job_id}", "status", JobStatus.CANCELLING)
    return {"status": "cancelling", "job_id": job_id}


@router.post("/jobs/{job_id}/retry")
async def force_retry_job(
    job_id: str,
    user: CurrentUser = Depends(require_admin),
):
    r = await get_redis()
    data = await r.hgetall(f"gpu:jobs:{job_id}")
    if not data:
        raise HTTPException(status_code=404, detail="Job not found")
    await r.hset(f"gpu:jobs:{job_id}", "status", JobStatus.QUEUED)
    # Re-queue only the original JobRequest fields (not stale runtime state)
    job_request = {
        "user_id": data.get("user_id") or "anonymous",
        "instance_type": data.get("instance_type") or "g6.xlarge",
        "checkpoint_enabled": data.get("checkpoint_enabled", "false").lower() == "true",
        "webhook_url": data.get("webhook_url") or None,
    }
    await r.lpush("gpu:job:queue", json.dumps(job_request))
    return {"status": "queued", "job_id": job_id}


@router.get("/regions")
async def get_regions(user: CurrentUser = Depends(require_admin)):
    r = await get_redis()
    settings = get_settings()
    regions = []
    for region in settings.regions:
        cap = await r.get(f"gpu:capacity:{region}")
        regions.append({
            "region": region,
            "available_capacity": int(cap) if cap else 0,
        })
    return {"regions": regions}


class CapacityUpdate(BaseModel):
    capacity: int


@router.put("/regions/{region}/capacity")
async def update_capacity(
    region: str,
    body: CapacityUpdate,
    user: CurrentUser = Depends(require_admin),
):
    r = await get_redis()
    await r.set(f"gpu:capacity:{region}", str(body.capacity))
    return {"region": region, "capacity": body.capacity}


@router.get("/stats")
async def get_stats(user: CurrentUser = Depends(require_admin)):
    r = await get_redis()
    active_count = await r.scard("gpu:active_jobs")
    queue_len = await r.llen("gpu:job:queue")
    return {
        "active_jobs": active_count,
        "queue_depth": queue_len,
    }
