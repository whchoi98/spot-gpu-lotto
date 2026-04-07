import json
import pytest


@pytest.fixture
async def redis_with_prices(redis):
    """Seed Redis with spot prices and capacity."""
    await redis.zadd("gpu:spot:prices", {
        "us-east-2:g6.xlarge": 0.2261,
        "us-east-1:g6.xlarge": 0.3608,
        "us-west-2:g6.xlarge": 0.4402,
        "us-east-2:g5.xlarge": 0.2500,
    })
    await redis.set("gpu:capacity:us-east-1", "4")
    await redis.set("gpu:capacity:us-east-2", "4")
    await redis.set("gpu:capacity:us-west-2", "4")
    return redis


async def test_check_spot_prices_all(redis_with_prices):
    from agent.tools import check_spot_prices_impl
    result = json.loads(await check_spot_prices_impl(redis_with_prices))
    assert len(result) == 4
    assert result[0]["price"] == pytest.approx(0.2261)
    assert result[0]["region"] == "us-east-2"


async def test_check_spot_prices_filtered(redis_with_prices):
    from agent.tools import check_spot_prices_impl
    result = json.loads(
        await check_spot_prices_impl(redis_with_prices, instance_type="g5.xlarge")
    )
    assert len(result) == 1
    assert result[0]["instance_type"] == "g5.xlarge"


async def test_check_spot_prices_with_capacity(redis_with_prices):
    from agent.tools import check_spot_prices_impl
    await redis_with_prices.set("gpu:capacity:us-east-2", "0")
    result = json.loads(await check_spot_prices_impl(redis_with_prices))
    east2 = [r for r in result if r["region"] == "us-east-2"]
    assert east2[0]["available_capacity"] == 0


async def test_submit_job(redis_with_prices):
    from agent.tools import submit_job_impl
    result = json.loads(await submit_job_impl(
        redis_with_prices,
        instance_type="g6.xlarge",
        image="nvidia/cuda:12.0-base",
        command="/bin/sh -c 'nvidia-smi'",
    ))
    assert result["status"] == "queued"
    queue_len = await redis_with_prices.llen("gpu:job:queue")
    assert queue_len == 1


async def test_get_job_status_found(redis_with_prices):
    from agent.tools import get_job_status_impl
    await redis_with_prices.hset("gpu:jobs:test-123", mapping={
        "job_id": "test-123",
        "user_id": "user1",
        "region": "us-east-1",
        "status": "running",
        "pod_name": "gpu-job-test1234",
        "instance_type": "g6.xlarge",
        "created_at": "1700000000",
    })
    result = json.loads(await get_job_status_impl(redis_with_prices, "test-123"))
    assert result["status"] == "running"
    assert result["region"] == "us-east-1"


async def test_get_job_status_not_found(redis_with_prices):
    from agent.tools import get_job_status_impl
    result = json.loads(await get_job_status_impl(redis_with_prices, "nonexistent"))
    assert result["error"] == "job_not_found"


async def test_list_active_jobs(redis_with_prices):
    from agent.tools import list_active_jobs_impl
    await redis_with_prices.sadd("gpu:active_jobs", "job-1", "job-2")
    await redis_with_prices.hset("gpu:jobs:job-1", mapping={
        "job_id": "job-1", "user_id": "u1", "region": "us-east-1",
        "status": "running", "pod_name": "p1", "instance_type": "g6.xlarge",
        "created_at": "1700000000",
    })
    await redis_with_prices.hset("gpu:jobs:job-2", mapping={
        "job_id": "job-2", "user_id": "u2", "region": "us-west-2",
        "status": "running", "pod_name": "p2", "instance_type": "g5.xlarge",
        "created_at": "1700000100",
    })
    result = json.loads(await list_active_jobs_impl(redis_with_prices))
    assert len(result) == 2


async def test_failure_history(redis_with_prices):
    from agent.tools import get_failure_history_impl
    for i, region in enumerate(["us-east-1", "us-east-1", "us-west-2"]):
        await redis_with_prices.hset(f"gpu:jobs:fail-{i}", mapping={
            "job_id": f"fail-{i}", "user_id": "u1", "region": region,
            "status": "failed", "pod_name": f"p{i}", "instance_type": "g6.xlarge",
            "created_at": str(1700000000 + i),
            "finished_at": str(1700000100 + i),
            "error_reason": "preempted" if region == "us-east-1" else "timeout",
        })
        await redis_with_prices.sadd("gpu:finished_jobs", f"fail-{i}")
    result = json.loads(await get_failure_history_impl(redis_with_prices))
    assert result["total_failures"] == 3
    assert result["by_region"]["us-east-1"] == 2
    assert result["by_reason"]["preempted"] == 2
