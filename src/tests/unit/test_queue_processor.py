"""Tests for dispatcher.queue_processor — dispatch path, retry, and capacity fallback."""
import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


@pytest.fixture
def job_payload():
    return json.dumps({
        "instance_type": "g6.xlarge",
        "image": "nvidia/cuda:12.0-base",
        "command": ["/bin/sh", "-c", "nvidia-smi"],
        "gpu_count": 1,
        "user_id": "user-abc",
        "checkpoint_enabled": False,
    })


@pytest.fixture
def mock_pod():
    pod = MagicMock()
    pod.metadata.name = "gpu-job-test1234"
    return pod


@pytest.fixture
def dry_run_settings():
    from common.config import Settings
    return Settings(redis_url="redis://localhost", k8s_mode="dry-run", max_retries=2)


@pytest.fixture
def live_settings():
    from common.config import Settings
    return Settings(redis_url="redis://localhost", k8s_mode="live", max_retries=2)


async def test_dispatch_success_dry_run(redis, job_payload, mock_pod, dry_run_settings):
    """Successful dispatch in dry-run mode — no k8s call, job recorded in Redis."""
    with (
        patch("dispatcher.queue_processor.get_settings", return_value=dry_run_settings),
        patch("dispatcher.queue_processor.select_region", new_callable=AsyncMock) as mock_sel,
        patch("dispatcher.queue_processor.build_gpu_pod", return_value=mock_pod),
        patch("dispatcher.queue_processor.notify_job_status", new_callable=AsyncMock),
    ):
        mock_sel.return_value = ("us-east-2", 0.2261)

        from dispatcher.queue_processor import process_one_job
        result = await process_one_job(redis, job_payload)

    assert result["status"] == "running"
    assert result["region"] == "us-east-2"
    assert result["spot_price"] == 0.2261
    job_id = result["job_id"]

    # Verify job recorded in Redis
    job_data = await redis.hgetall(f"gpu:jobs:{job_id}")
    assert job_data["region"] == "us-east-2"
    assert job_data["status"] == "running"
    assert job_data["instance_type"] == "g6.xlarge"
    assert job_data["user_id"] == "user-abc"

    # Verify added to active jobs set
    assert await redis.sismember("gpu:active_jobs", job_id)


async def test_dispatch_success_live_mode(redis, job_payload, mock_pod, live_settings):
    """Successful dispatch in live mode — k8s client called."""
    mock_k8s = MagicMock()
    with (
        patch("dispatcher.queue_processor.get_settings", return_value=live_settings),
        patch("dispatcher.queue_processor.select_region", new_callable=AsyncMock) as mock_sel,
        patch("dispatcher.queue_processor.build_gpu_pod", return_value=mock_pod),
        patch("dispatcher.queue_processor.get_k8s_client", return_value=mock_k8s),
        patch("dispatcher.queue_processor.notify_job_status", new_callable=AsyncMock),
    ):
        mock_sel.return_value = ("us-east-1", 0.3608)

        from dispatcher.queue_processor import process_one_job
        result = await process_one_job(redis, job_payload)

    assert result["status"] == "running"
    assert result["region"] == "us-east-1"
    mock_k8s.create_namespaced_pod.assert_called_once_with(
        namespace="gpu-jobs", body=mock_pod
    )


async def test_no_capacity_requeue(redis, job_payload, dry_run_settings):
    """No capacity with retries remaining — job requeued."""
    with (
        patch("dispatcher.queue_processor.get_settings", return_value=dry_run_settings),
        patch("dispatcher.queue_processor.select_region", new_callable=AsyncMock) as mock_sel,
    ):
        mock_sel.return_value = None

        from dispatcher.queue_processor import process_one_job
        result = await process_one_job(redis, job_payload)

    assert result["status"] == "requeued"

    # Verify job was pushed back to queue with incremented retry count
    queued = await redis.lpop("gpu:job:queue")
    requeued_job = json.loads(queued)
    assert requeued_job["_retry_count"] == 1


async def test_no_capacity_max_retries_fail(redis, dry_run_settings):
    """No capacity after max retries — job fails."""
    job_with_retries = json.dumps({
        "instance_type": "g6.xlarge",
        "image": "test:latest",
        "_retry_count": 2,  # already at max_retries (2)
    })
    with (
        patch("dispatcher.queue_processor.get_settings", return_value=dry_run_settings),
        patch("dispatcher.queue_processor.select_region", new_callable=AsyncMock) as mock_sel,
    ):
        mock_sel.return_value = None

        from dispatcher.queue_processor import process_one_job
        result = await process_one_job(redis, job_with_retries)

    assert result["status"] == "failed"
    assert result["error"] == "no_capacity"


async def test_live_mode_k8s_unauthorized_invalidates_client(
    redis, job_payload, mock_pod, live_settings
):
    """K8s 401 error triggers client cache invalidation and re-raises."""
    mock_k8s = MagicMock()
    mock_k8s.create_namespaced_pod.side_effect = Exception("Unauthorized 401")

    with (
        patch("dispatcher.queue_processor.get_settings", return_value=live_settings),
        patch("dispatcher.queue_processor.select_region", new_callable=AsyncMock) as mock_sel,
        patch("dispatcher.queue_processor.build_gpu_pod", return_value=mock_pod),
        patch("dispatcher.queue_processor.get_k8s_client", return_value=mock_k8s),
        patch("dispatcher.queue_processor.invalidate_client") as mock_inv,
        patch("dispatcher.queue_processor.notify_job_status", new_callable=AsyncMock),
    ):
        mock_sel.return_value = ("us-east-1", 0.36)

        from dispatcher.queue_processor import process_one_job
        with pytest.raises(Exception, match="Unauthorized"):
            await process_one_job(redis, job_payload)

        mock_inv.assert_called_once_with("us-east-1")


async def test_default_instance_type(redis, mock_pod, dry_run_settings):
    """Job without instance_type defaults to g6.xlarge."""
    job_no_type = json.dumps({"image": "test:latest"})
    with (
        patch("dispatcher.queue_processor.get_settings", return_value=dry_run_settings),
        patch("dispatcher.queue_processor.select_region", new_callable=AsyncMock) as mock_sel,
        patch("dispatcher.queue_processor.build_gpu_pod", return_value=mock_pod),
        patch("dispatcher.queue_processor.notify_job_status", new_callable=AsyncMock),
    ):
        mock_sel.return_value = ("us-west-2", 0.44)

        from dispatcher.queue_processor import process_one_job
        result = await process_one_job(redis, job_no_type)

    assert result["status"] == "running"
    job_data = await redis.hgetall(f"gpu:jobs:{result['job_id']}")
    assert job_data["instance_type"] == "g6.xlarge"


async def test_notification_called_on_dispatch(redis, job_payload, mock_pod, dry_run_settings):
    """notify_job_status called with correct args after dispatch."""
    with (
        patch("dispatcher.queue_processor.get_settings", return_value=dry_run_settings),
        patch("dispatcher.queue_processor.select_region", new_callable=AsyncMock) as mock_sel,
        patch("dispatcher.queue_processor.build_gpu_pod", return_value=mock_pod),
        patch(
            "dispatcher.queue_processor.notify_job_status", new_callable=AsyncMock
        ) as mock_notify,
    ):
        mock_sel.return_value = ("us-east-2", 0.22)

        from dispatcher.queue_processor import process_one_job
        result = await process_one_job(redis, job_payload)

    mock_notify.assert_called_once()
    call_args = mock_notify.call_args
    assert call_args[0][1] == result["job_id"]
    assert call_args[0][2] == "running"
    assert call_args[1]["region"] == "us-east-2"
    assert call_args[1]["spot_price"] == 0.22
