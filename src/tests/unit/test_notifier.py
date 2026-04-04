import json
from unittest.mock import AsyncMock, patch

import httpx

from dispatcher.notifier import notify_job_status, publish_status, send_webhook


async def test_publish_status(redis):
    """Test Redis Pub/Sub publish."""
    # Subscribe first
    pubsub = redis.pubsub()
    await pubsub.subscribe("gpu:jobs:test-123:status")
    # Consume the subscribe confirmation message
    await pubsub.get_message(timeout=1)

    await publish_status(redis, "test-123", "running", region="us-east-2")

    msg = await pubsub.get_message(timeout=1)
    assert msg is not None
    assert msg["type"] == "message"
    data = json.loads(msg["data"])
    assert data["job_id"] == "test-123"
    assert data["status"] == "running"
    assert data["region"] == "us-east-2"

    await pubsub.unsubscribe()
    await pubsub.aclose()


async def test_send_webhook_success():
    """Test successful webhook delivery."""
    with patch("dispatcher.notifier.httpx.AsyncClient") as mock_client_cls:
        mock_client = AsyncMock()
        mock_resp = AsyncMock()
        mock_resp.status_code = 200
        mock_resp.raise_for_status = AsyncMock()
        mock_client.post.return_value = mock_resp
        mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        result = await send_webhook("https://hooks.example.com/test", {"job_id": "abc"})
        assert result is True
        mock_client.post.assert_called_once_with(
            "https://hooks.example.com/test", json={"job_id": "abc"}
        )


async def test_send_webhook_failure():
    """Test webhook failure handling."""
    with patch("dispatcher.notifier.httpx.AsyncClient") as mock_client_cls:
        mock_client = AsyncMock()
        mock_client.post.side_effect = httpx.ConnectError("connection refused")
        mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=False)

        result = await send_webhook("https://hooks.example.com/test", {"job_id": "abc"})
        assert result is False


async def test_notify_sends_pubsub_and_webhook(redis):
    """Test combined notification."""
    pubsub = redis.pubsub()
    await pubsub.subscribe("gpu:jobs:notify-test:status")
    await pubsub.get_message(timeout=1)

    with patch("dispatcher.notifier.send_webhook", new_callable=AsyncMock) as mock_wh:
        mock_wh.return_value = True
        await notify_job_status(
            redis, "notify-test", "succeeded",
            webhook_url="https://hooks.example.com/done",
            region="us-east-1",
        )
        mock_wh.assert_called_once()
        call_args = mock_wh.call_args
        assert call_args[0][0] == "https://hooks.example.com/done"
        assert call_args[0][1]["status"] == "succeeded"

    # Check Pub/Sub message was sent
    msg = await pubsub.get_message(timeout=1)
    assert msg is not None
    data = json.loads(msg["data"])
    assert data["status"] == "succeeded"

    await pubsub.unsubscribe()
    await pubsub.aclose()


async def test_notify_no_webhook_for_running(redis):
    """Webhook should not be sent for non-terminal statuses."""
    with patch("dispatcher.notifier.send_webhook", new_callable=AsyncMock) as mock_wh:
        await notify_job_status(
            redis, "run-test", "running",
            webhook_url="https://hooks.example.com/x",
        )
        mock_wh.assert_not_called()
