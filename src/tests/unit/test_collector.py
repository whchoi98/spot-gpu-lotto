import pytest
from price_watcher.collector import collect_mock_prices, update_prices, collect_all_prices


REGIONS = ["us-east-1", "us-east-2", "us-west-2"]
INSTANCE_TYPES = ["g6.xlarge", "g5.xlarge", "g6e.xlarge", "g6e.2xlarge", "g5.12xlarge", "g5.48xlarge"]


async def test_mock_prices_count():
    """Mock mode produces prices for all region×instance combinations."""
    prices = await collect_mock_prices(REGIONS, INSTANCE_TYPES)
    assert len(prices) == len(REGIONS) * len(INSTANCE_TYPES)


async def test_mock_prices_structure():
    """Mock prices have required fields."""
    prices = await collect_mock_prices(REGIONS, INSTANCE_TYPES)
    for p in prices:
        assert "region" in p
        assert "instance_type" in p
        assert "price" in p
        assert isinstance(p["price"], float)
        assert p["price"] > 0


async def test_update_prices(redis):
    """update_prices writes to Redis sorted set."""
    prices = [
        {"region": "us-east-1", "instance_type": "g6.xlarge", "price": 0.30},
        {"region": "us-east-2", "instance_type": "g6.xlarge", "price": 0.25},
    ]
    count = await update_prices(redis, prices)
    assert count == 2
    # Verify sorted set
    result = await redis.zrange("gpu:spot:prices", 0, -1, withscores=True)
    assert len(result) == 2
    members = {m: s for m, s in result}
    assert members["us-east-2:g6.xlarge"] == pytest.approx(0.25)
    assert members["us-east-1:g6.xlarge"] == pytest.approx(0.30)


async def test_update_prices_upsert(redis):
    """ZADD upserts — new price overwrites old."""
    prices1 = [{"region": "us-east-1", "instance_type": "g6.xlarge", "price": 0.50}]
    await update_prices(redis, prices1)
    prices2 = [{"region": "us-east-1", "instance_type": "g6.xlarge", "price": 0.30}]
    await update_prices(redis, prices2)
    score = await redis.zscore("gpu:spot:prices", "us-east-1:g6.xlarge")
    assert score == pytest.approx(0.30)


async def test_update_prices_empty(redis):
    """Empty prices list returns 0."""
    count = await update_prices(redis, [])
    assert count == 0


async def test_collect_all_mock():
    """collect_all_prices in mock mode works."""
    prices = await collect_all_prices(REGIONS, INSTANCE_TYPES, mock=True)
    assert len(prices) == 18  # 3 regions × 6 types
    for p in prices:
        assert p["price"] > 0
