"""Spot price query endpoint."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from common.redis_client import get_redis
from api_server.auth import get_current_user, CurrentUser

router = APIRouter(prefix="/api", tags=["prices"])


@router.get("/prices")
async def get_prices(
    instance_type: str | None = Query(None, description="Filter by instance type"),
    user: CurrentUser = Depends(get_current_user),
):
    """Return current Spot prices from all regions."""
    r = await get_redis()
    all_prices = await r.zrange("gpu:spot:prices", 0, -1, withscores=True)

    prices = []
    for member, score in all_prices:
        region, itype = member.rsplit(":", 1)
        if instance_type and itype != instance_type:
            continue
        prices.append({
            "region": region,
            "instance_type": itype,
            "price": score,
        })

    return {"prices": prices}
