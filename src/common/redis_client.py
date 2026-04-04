"""Async Redis client factory with connection pooling."""
import redis.asyncio as aioredis

from common.config import get_settings

_pool: aioredis.Redis | None = None


async def get_redis() -> aioredis.Redis:
    """Get or create a shared async Redis connection."""
    global _pool
    if _pool is None:
        settings = get_settings()
        _pool = aioredis.from_url(
            settings.redis_url,
            decode_responses=True,
            max_connections=20,
        )
    return _pool


async def close_redis() -> None:
    """Close the Redis connection pool."""
    global _pool
    if _pool is not None:
        await _pool.aclose()
        _pool = None


async def redis_health() -> bool:
    """Check Redis connectivity."""
    try:
        r = await get_redis()
        return await r.ping()
    except Exception:
        return False
