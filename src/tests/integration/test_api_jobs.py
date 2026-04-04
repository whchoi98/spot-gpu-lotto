import json
import time
import pytest
from unittest.mock import patch, AsyncMock
from httpx import AsyncClient, ASGITransport
from api_server.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


async def test_submit_job(client, redis):
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch("api_server.routes.jobs.get_redis", new_callable=AsyncMock, return_value=redis):
            resp = await client.post("/api/jobs", json={
                "user_id": "test-user",
                "image": "my-ml:latest",
                "instance_type": "g6.xlarge",
            })
    assert resp.status_code == 200
    assert resp.json()["status"] == "queued"
    # Verify job was pushed to queue
    item = await redis.rpop("gpu:job:queue")
    assert item is not None
    data = json.loads(item)
    assert data["image"] == "my-ml:latest"


async def test_get_job(client, redis):
    # Seed a job
    await redis.hset("gpu:jobs:test-job-1", mapping={
        "job_id": "test-job-1",
        "user_id": "dev-user",
        "region": "us-east-2",
        "status": "running",
        "pod_name": "gpu-job-test-job",
        "instance_type": "g6.xlarge",
        "created_at": str(int(time.time())),
    })
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch("api_server.routes.jobs.get_redis", new_callable=AsyncMock, return_value=redis):
            resp = await client.get("/api/jobs/test-job-1")
    assert resp.status_code == 200
    assert resp.json()["job_id"] == "test-job-1"
    assert resp.json()["status"] == "running"


async def test_get_job_not_found(client, redis):
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch("api_server.routes.jobs.get_redis", new_callable=AsyncMock, return_value=redis):
            resp = await client.get("/api/jobs/nonexistent")
    assert resp.status_code == 404


async def test_cancel_job(client, redis):
    await redis.hset("gpu:jobs:cancel-test", mapping={
        "job_id": "cancel-test",
        "user_id": "dev-user",
        "region": "us-east-2",
        "status": "running",
        "pod_name": "gpu-job-cancel-t",
        "instance_type": "g6.xlarge",
        "created_at": str(int(time.time())),
    })
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch("api_server.routes.jobs.get_redis", new_callable=AsyncMock, return_value=redis):
            resp = await client.delete("/api/jobs/cancel-test")
    assert resp.status_code == 200
    assert resp.json()["status"] == "cancelling"
    status = await redis.hget("gpu:jobs:cancel-test", "status")
    assert status == "cancelling"


async def test_cancel_completed_job_fails(client, redis):
    await redis.hset("gpu:jobs:done-test", mapping={
        "job_id": "done-test",
        "user_id": "dev-user",
        "region": "us-east-2",
        "status": "succeeded",
        "pod_name": "gpu-job-done-tes",
        "instance_type": "g6.xlarge",
        "created_at": str(int(time.time())),
    })
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch("api_server.routes.jobs.get_redis", new_callable=AsyncMock, return_value=redis):
            resp = await client.delete("/api/jobs/done-test")
    assert resp.status_code == 400
