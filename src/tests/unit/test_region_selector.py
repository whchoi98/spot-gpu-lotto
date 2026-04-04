import pytest


@pytest.fixture
async def redis_with_prices(redis):
    """Seed Redis with sorted set of prices."""
    await redis.zadd("gpu:spot:prices", {
        "us-east-2:g6.xlarge": 0.2261,
        "us-east-1:g6.xlarge": 0.3608,
        "us-west-2:g6.xlarge": 0.4402,
        "us-east-2:g5.xlarge": 0.2500,
        "us-east-1:g5.xlarge": 0.3800,
    })
    await redis.set("gpu:capacity:us-east-1", "4")
    await redis.set("gpu:capacity:us-east-2", "4")
    await redis.set("gpu:capacity:us-west-2", "4")
    return redis


async def test_cheapest_region(redis_with_prices):
    from dispatcher.region_selector import select_region
    region, price = await select_region(redis_with_prices, "g6.xlarge")
    assert region == "us-east-2"
    assert price == pytest.approx(0.2261)


async def test_cheapest_different_instance(redis_with_prices):
    from dispatcher.region_selector import select_region
    region, price = await select_region(redis_with_prices, "g5.xlarge")
    assert region == "us-east-2"
    assert price == pytest.approx(0.2500)


async def test_fallback_when_cheapest_full(redis_with_prices):
    from dispatcher.region_selector import select_region
    await redis_with_prices.set("gpu:capacity:us-east-2", "0")
    region, price = await select_region(redis_with_prices, "g6.xlarge")
    assert region == "us-east-1"
    assert price == pytest.approx(0.3608)


async def test_all_regions_full(redis_with_prices):
    from dispatcher.region_selector import select_region
    await redis_with_prices.set("gpu:capacity:us-east-1", "0")
    await redis_with_prices.set("gpu:capacity:us-east-2", "0")
    await redis_with_prices.set("gpu:capacity:us-west-2", "0")
    result = await select_region(redis_with_prices, "g6.xlarge")
    assert result is None


async def test_no_prices_for_instance(redis_with_prices):
    from dispatcher.region_selector import select_region
    result = await select_region(redis_with_prices, "p4d.24xlarge")
    assert result is None


async def test_exclude_region(redis_with_prices):
    from dispatcher.region_selector import select_region
    region, price = await select_region(
        redis_with_prices, "g6.xlarge", exclude_regions={"us-east-2"}
    )
    assert region == "us-east-1"
