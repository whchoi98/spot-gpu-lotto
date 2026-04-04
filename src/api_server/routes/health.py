"""Health check endpoints (no authentication required)."""
from fastapi import APIRouter

from common.redis_client import redis_health

router = APIRouter(tags=["health"])


@router.get("/healthz")
async def healthz():
    return {"status": "ok"}


@router.get("/readyz")
async def readyz():
    healthy = await redis_health()
    if healthy:
        return {"status": "ok", "redis": "connected"}
    return {"status": "degraded", "redis": "disconnected"}
