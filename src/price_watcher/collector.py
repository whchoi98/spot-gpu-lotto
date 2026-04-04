"""Collect GPU Spot instance prices from AWS across regions."""
import asyncio
import random

import aioboto3
import redis.asyncio as aioredis

from common.logging import get_logger

log = get_logger("collector")


async def collect_region_prices(region: str, instance_types: list[str]) -> list[dict]:
    """Fetch current Spot prices for given instance types in a region."""
    session = aioboto3.Session()
    prices = []
    async with session.client("ec2", region_name=region) as ec2:
        paginator = ec2.get_paginator("describe_spot_price_history")
        async for page in paginator.paginate(
            InstanceTypes=instance_types,
            ProductDescriptions=["Linux/UNIX"],
            MaxResults=100,
        ):
            for item in page["SpotPriceHistory"]:
                prices.append({
                    "region": region,
                    "instance_type": item["InstanceType"],
                    "price": float(item["SpotPrice"]),
                    "az": item["AvailabilityZone"],
                })
    # Deduplicate: keep lowest price per instance type in the region
    best: dict[str, dict] = {}
    for p in prices:
        key = p["instance_type"]
        if key not in best or p["price"] < best[key]["price"]:
            best[key] = p
    return list(best.values())


async def collect_mock_prices(
    regions: list[str], instance_types: list[str]
) -> list[dict]:
    """Generate mock prices for local development."""
    base_prices = {
        "g6.xlarge": 0.30, "g5.xlarge": 0.35,
        "g6e.xlarge": 0.55, "g6e.2xlarge": 0.75,
        "g5.12xlarge": 2.50, "g5.48xlarge": 8.00,
    }
    prices = []
    for region in regions:
        for itype in instance_types:
            base = base_prices.get(itype, 0.50)
            jitter = random.uniform(-0.05, 0.05)
            prices.append({
                "region": region,
                "instance_type": itype,
                "price": round(base + jitter, 4),
            })
    return prices


async def collect_all_prices(
    regions: list[str], instance_types: list[str], mock: bool = False
) -> list[dict]:
    """Collect prices from all regions in parallel."""
    if mock:
        return await collect_mock_prices(regions, instance_types)

    tasks = [collect_region_prices(r, instance_types) for r in regions]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    all_prices = []
    for region, result in zip(regions, results):
        if isinstance(result, Exception):
            log.error("price_fetch_failed", region=region, error=str(result))
            continue
        all_prices.extend(result)
    return all_prices


async def update_prices(r: aioredis.Redis, prices: list[dict]) -> int:
    """Write collected prices to Redis Sorted Set using ZADD upsert.
    Returns the number of prices updated."""
    if not prices:
        return 0
    mapping = {}
    for p in prices:
        key = f"{p['region']}:{p['instance_type']}"
        mapping[key] = p["price"]
    await r.zadd("gpu:spot:prices", mapping)
    log.info("prices_updated", count=len(mapping))
    return len(mapping)
