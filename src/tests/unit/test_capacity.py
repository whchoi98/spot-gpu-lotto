import pytest


@pytest.fixture
async def redis_with_capacity(redis):
    """Seed Redis with capacity for 3 regions."""
    await redis.set("gpu:capacity:us-east-1", "4")
    await redis.set("gpu:capacity:us-east-2", "4")
    await redis.set("gpu:capacity:us-west-2", "4")
    return redis


async def test_acquire_capacity_success(redis_with_capacity):
    from dispatcher.capacity import acquire_capacity
    result = await acquire_capacity(redis_with_capacity, "us-east-2")
    assert result is True
    cap = await redis_with_capacity.get("gpu:capacity:us-east-2")
    assert int(cap) == 3


async def test_acquire_capacity_at_zero(redis):
    from dispatcher.capacity import acquire_capacity
    await redis.set("gpu:capacity:us-east-1", "0")
    result = await acquire_capacity(redis, "us-east-1")
    assert result is False
    cap = await redis.get("gpu:capacity:us-east-1")
    assert int(cap) == 0


async def test_release_capacity(redis_with_capacity):
    from dispatcher.capacity import release_capacity
    await release_capacity(redis_with_capacity, "us-east-2")
    cap = await redis_with_capacity.get("gpu:capacity:us-east-2")
    assert int(cap) == 5


async def test_init_capacity(redis):
    from dispatcher.capacity import init_capacity
    await init_capacity(redis, ["us-east-1", "us-east-2"], capacity=8)
    assert int(await redis.get("gpu:capacity:us-east-1")) == 8
    assert int(await redis.get("gpu:capacity:us-east-2")) == 8
