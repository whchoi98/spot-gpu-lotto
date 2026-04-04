"""Atomic GPU capacity management using Redis."""
import redis.asyncio as aioredis


async def acquire_capacity(r: aioredis.Redis, region: str) -> bool:
    """
    Atomically try to acquire one GPU slot in the region.
    
    In production with real Redis, this could use a Lua script for guaranteed atomicity.
    For testing/FakeRedis compatibility, we use a transaction.
    """
    key = f"gpu:capacity:{region}"
    
    # Use a transaction for atomicity
    async with r.pipeline(transaction=True) as pipe:
        while True:
            try:
                # Watch the key for changes
                await pipe.watch(key)
                
                # Get current capacity (outside transaction)
                cap = await pipe.get(key)
                
                if cap is None:
                    # Key doesn't exist
                    await pipe.unwatch()
                    return False
                
                cap_val = int(cap)
                if cap_val <= 0:
                    await pipe.unwatch()
                    return False
                
                # Try to decrement atomically
                pipe.multi()
                pipe.decr(key)
                await pipe.execute()
                return True
            except aioredis.WatchError:
                # Key was modified, retry
                continue


async def release_capacity(r: aioredis.Redis, region: str) -> None:
    """Return one GPU slot to the region."""
    await r.incr(f"gpu:capacity:{region}")


async def init_capacity(r: aioredis.Redis, regions: list[str], capacity: int) -> None:
    """Initialize capacity counters for all regions (only if not already set)."""
    for region in regions:
        key = f"gpu:capacity:{region}"
        exists = await r.exists(key)
        if not exists:
            await r.set(key, str(capacity))
