"""Job status notification via Redis Pub/Sub and webhooks."""
import json

import httpx
import redis.asyncio as aioredis

from common.logging import get_logger

log = get_logger("notifier")


async def publish_status(r: aioredis.Redis, job_id: str, status: str, **extra) -> None:
    """Publish job status change to Redis Pub/Sub (for SSE consumers)."""
    message = json.dumps({"job_id": job_id, "status": status, **extra})
    channel = f"gpu:jobs:{job_id}:status"
    await r.publish(channel, message)
    log.info("status_published", job_id=job_id, status=status, channel=channel)


async def send_webhook(webhook_url: str, payload: dict) -> bool:
    """Send webhook notification. Returns True on success."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(webhook_url, json=payload)
            resp.raise_for_status()
            log.info("webhook_sent", url=webhook_url, status_code=resp.status_code)
            return True
    except Exception as e:
        log.warning("webhook_failed", url=webhook_url, error=str(e))
        return False


async def notify_job_status(
    r: aioredis.Redis,
    job_id: str,
    status: str,
    webhook_url: str | None = None,
    **extra,
) -> None:
    """Publish status via Pub/Sub and optionally send webhook."""
    await publish_status(r, job_id, status, **extra)
    if webhook_url and status in ("succeeded", "failed", "cancelled"):
        payload = {"job_id": job_id, "status": status, **extra}
        await send_webhook(webhook_url, payload)
