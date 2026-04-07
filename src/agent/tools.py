"""Strands @tool functions wrapping GPU Spot Lotto operations.

Each tool has an `_impl` async function (testable with fakeredis)
and a sync @tool wrapper that resolves the Redis dependency at call time.
"""
import json

import redis.asyncio as aioredis


async def check_spot_prices_impl(
    r: aioredis.Redis,
    instance_type: str | None = None,
    region: str | None = None,
) -> str:
    """Query current GPU Spot prices from Redis sorted set.

    Returns JSON array sorted by price ascending, each entry:
    {"region", "instance_type", "price", "available_capacity"}
    """
    all_prices = await r.zrange("gpu:spot:prices", 0, -1, withscores=True)
    results = []
    for member, score in all_prices:
        rgn, itype = member.rsplit(":", 1)
        if instance_type and itype != instance_type:
            continue
        if region and rgn != region:
            continue
        cap = await r.get(f"gpu:capacity:{rgn}")
        results.append({
            "region": rgn,
            "instance_type": itype,
            "price": round(score, 4),
            "available_capacity": int(cap) if cap else 0,
        })
    results.sort(key=lambda x: x["price"])
    return json.dumps(results)


async def submit_job_impl(
    r: aioredis.Redis,
    instance_type: str = "g6.xlarge",
    image: str = "nvidia/cuda:12.0-base",
    command: str = "nvidia-smi && sleep 60",
    gpu_count: int = 1,
    checkpoint_enabled: bool = False,
) -> str:
    """Submit a GPU job to the dispatch queue.

    Returns JSON with {status: "queued"} on success.
    """
    job = {
        "instance_type": instance_type,
        "image": image,
        "command": ["/bin/sh", "-c", command],
        "gpu_count": gpu_count,
        "checkpoint_enabled": checkpoint_enabled,
    }
    await r.lpush("gpu:job:queue", json.dumps(job))
    return json.dumps({"status": "queued", "instance_type": instance_type})


async def get_job_status_impl(r: aioredis.Redis, job_id: str) -> str:
    """Get the current status of a GPU job by its ID."""
    data = await r.hgetall(f"gpu:jobs:{job_id}")
    if not data:
        return json.dumps({"error": "job_not_found", "job_id": job_id})
    return json.dumps({
        "job_id": data.get("job_id"),
        "status": data.get("status"),
        "region": data.get("region"),
        "instance_type": data.get("instance_type"),
        "created_at": data.get("created_at"),
        "error_reason": data.get("error_reason"),
    })


async def list_active_jobs_impl(r: aioredis.Redis) -> str:
    """List all currently active GPU jobs."""
    job_ids = await r.smembers("gpu:active_jobs")
    jobs = []
    for jid in sorted(job_ids):
        data = await r.hgetall(f"gpu:jobs:{jid}")
        if data:
            jobs.append({
                "job_id": data.get("job_id"),
                "status": data.get("status"),
                "region": data.get("region"),
                "instance_type": data.get("instance_type"),
            })
    return json.dumps(jobs)


async def get_failure_history_impl(r: aioredis.Redis) -> str:
    """Analyze recent job failure patterns by region and error reason."""
    job_ids = await r.smembers("gpu:finished_jobs")
    by_region: dict[str, int] = {}
    by_reason: dict[str, int] = {}
    total = 0
    for jid in job_ids:
        data = await r.hgetall(f"gpu:jobs:{jid}")
        if data.get("status") == "failed":
            total += 1
            rgn = data.get("region", "unknown")
            reason = data.get("error_reason", "unknown")
            by_region[rgn] = by_region.get(rgn, 0) + 1
            by_reason[reason] = by_reason.get(reason, 0) + 1
    return json.dumps({
        "total_failures": total,
        "by_region": by_region,
        "by_reason": by_reason,
    })
