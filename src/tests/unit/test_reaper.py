# src/tests/unit/test_reaper.py
import time
import pytest
from unittest.mock import patch, AsyncMock
from common.models import JobStatus
from dispatcher.reaper import reap_job


@pytest.fixture
async def running_job(redis):
    """Seed Redis with a running job."""
    job_id = "reap-test-001"
    await redis.hset(f"gpu:jobs:{job_id}", mapping={
        "job_id": job_id,
        "user_id": "user1",
        "region": "us-east-2",
        "status": "running",
        "pod_name": "gpu-job-reap-tes",
        "instance_type": "g6.xlarge",
        "created_at": str(int(time.time())),
        "retry_count": "0",
        "checkpoint_enabled": "false",
    })
    await redis.sadd("gpu:active_jobs", job_id)
    return job_id, redis


async def test_reap_succeeded(running_job):
    job_id, redis = running_job
    deleted_pods = []

    def mock_get_phase(region, pod_name):
        return "Succeeded"

    def mock_delete(region, pod_name):
        deleted_pods.append((region, pod_name))
        return True

    with patch("dispatcher.reaper.notify_job_status", new_callable=AsyncMock):
        result = await reap_job(redis, job_id, mock_get_phase, mock_delete)

    assert result == "succeeded"
    assert len(deleted_pods) == 1
    status = await redis.hget(f"gpu:jobs:{job_id}", "status")
    assert status == "succeeded"
    assert not await redis.sismember("gpu:active_jobs", job_id)


async def test_reap_failed_with_retry(running_job):
    job_id, redis = running_job
    requeued = []

    def mock_get_phase(region, pod_name):
        return "Failed"

    def mock_delete(region, pod_name):
        return True

    def mock_requeue(job, exclude_region):
        requeued.append(exclude_region)

    with patch("dispatcher.reaper.notify_job_status", new_callable=AsyncMock):
        with patch("dispatcher.reaper.get_settings") as mock_settings:
            mock_settings.return_value.max_retries = 2
            mock_settings.return_value.job_timeout = 7200
            result = await reap_job(redis, job_id, mock_get_phase, mock_delete, mock_requeue)

    assert result == "queued"
    assert len(requeued) == 1
    assert requeued[0] == "us-east-2"
    retry_count = await redis.hget(f"gpu:jobs:{job_id}", "retry_count")
    assert retry_count == "1"


async def test_reap_failed_max_retries(running_job):
    job_id, redis = running_job
    await redis.hset(f"gpu:jobs:{job_id}", "retry_count", "2")

    def mock_get_phase(region, pod_name):
        return "Failed"

    def mock_delete(region, pod_name):
        return True

    with patch("dispatcher.reaper.notify_job_status", new_callable=AsyncMock):
        with patch("dispatcher.reaper.get_settings") as mock_settings:
            mock_settings.return_value.max_retries = 2
            mock_settings.return_value.job_timeout = 7200
            result = await reap_job(redis, job_id, mock_get_phase, mock_delete)

    assert result == "failed"
    status = await redis.hget(f"gpu:jobs:{job_id}", "status")
    assert status == "failed"
    error = await redis.hget(f"gpu:jobs:{job_id}", "error_reason")
    assert error == "pod_failed"


async def test_reap_cancelling(running_job):
    job_id, redis = running_job
    await redis.hset(f"gpu:jobs:{job_id}", "status", "cancelling")
    deleted_pods = []

    def mock_get_phase(region, pod_name):
        return "Running"

    def mock_delete(region, pod_name):
        deleted_pods.append((region, pod_name))
        return True

    with patch("dispatcher.reaper.notify_job_status", new_callable=AsyncMock):
        with patch("dispatcher.reaper.get_settings") as mock_settings:
            mock_settings.return_value.max_retries = 2
            mock_settings.return_value.job_timeout = 7200
            result = await reap_job(redis, job_id, mock_get_phase, mock_delete)

    assert result == "cancelled"
    assert len(deleted_pods) == 1
    status = await redis.hget(f"gpu:jobs:{job_id}", "status")
    assert status == "cancelled"


async def test_reap_timeout(running_job):
    job_id, redis = running_job
    # Set created_at to past
    await redis.hset(f"gpu:jobs:{job_id}", "created_at", "1000000000")
    deleted_pods = []

    def mock_get_phase(region, pod_name):
        return "Running"

    def mock_delete(region, pod_name):
        deleted_pods.append(pod_name)
        return True

    with patch("dispatcher.reaper.notify_job_status", new_callable=AsyncMock):
        with patch("dispatcher.reaper.get_settings") as mock_settings:
            mock_settings.return_value.max_retries = 2
            mock_settings.return_value.job_timeout = 7200
            result = await reap_job(redis, job_id, mock_get_phase, mock_delete)

    assert result == "failed"
    error = await redis.hget(f"gpu:jobs:{job_id}", "error_reason")
    assert error == "timeout"


async def test_reap_missing_job(redis):
    """Job data missing from Redis."""
    await redis.sadd("gpu:active_jobs", "ghost-job")

    def mock_get_phase(region, pod_name):
        return None

    def mock_delete(region, pod_name):
        return True

    result = await reap_job(redis, "ghost-job", mock_get_phase, mock_delete)
    assert result is None
    assert not await redis.sismember("gpu:active_jobs", "ghost-job")
