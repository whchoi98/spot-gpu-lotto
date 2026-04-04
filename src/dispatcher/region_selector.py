"""Select the cheapest available Spot region for a given instance type."""
import redis.asyncio as aioredis

from dispatcher.capacity import acquire_capacity


async def select_region(
    r: aioredis.Redis,
    instance_type: str,
    exclude_regions: set[str] | None = None,
) -> tuple[str, float] | None:
    """Find the cheapest region with available capacity for the instance type.

    Returns (region, price) or None if no region is available.
    Atomically acquires capacity on the selected region.
    """
    exclude = exclude_regions or set()
    all_prices = await r.zrange("gpu:spot:prices", 0, -1, withscores=True)

    candidates = []
    for member, score in all_prices:
        region, itype = member.rsplit(":", 1)
        if itype == instance_type and region not in exclude:
            candidates.append((region, score))

    for region, price in candidates:
        acquired = await acquire_capacity(r, region)
        if acquired:
            return (region, price)

    return None
