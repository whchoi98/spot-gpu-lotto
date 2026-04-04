from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from api_server.auth import CurrentUser
from api_server.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
def admin_user():
    return CurrentUser(user_id="admin1", role="admin")


async def test_admin_stats(client, redis, admin_user):
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch("api_server.routes.admin.get_redis", new_callable=AsyncMock, return_value=redis):
            resp = await client.get("/api/admin/stats")
    assert resp.status_code == 200
    assert "active_jobs" in resp.json()
    assert "queue_depth" in resp.json()


async def test_admin_regions(client, redis, admin_user):
    await redis.set("gpu:capacity:us-east-1", "10")
    await redis.set("gpu:capacity:us-east-2", "8")
    await redis.set("gpu:capacity:us-west-2", "12")
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        mock_s.return_value.regions = ["us-east-1", "us-east-2", "us-west-2"]
        with patch("api_server.routes.admin.get_redis", new_callable=AsyncMock, return_value=redis):
            with patch("api_server.routes.admin.get_settings", return_value=mock_s.return_value):
                resp = await client.get("/api/admin/regions")
    assert resp.status_code == 200
    regions = resp.json()["regions"]
    assert len(regions) == 3


async def test_admin_update_capacity(client, redis, admin_user):
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch("api_server.routes.admin.get_redis", new_callable=AsyncMock, return_value=redis):
            resp = await client.put("/api/admin/regions/us-east-1/capacity", json={"capacity": 32})
    assert resp.status_code == 200
    cap = await redis.get("gpu:capacity:us-east-1")
    assert cap == "32"


async def test_admin_list_jobs(client, redis, admin_user):
    await redis.sadd("gpu:active_jobs", "job-1")
    await redis.hset("gpu:jobs:job-1", mapping={
        "job_id": "job-1", "user_id": "u1", "region": "us-east-1",
        "status": "running", "pod_name": "p1", "instance_type": "g6.xlarge",
        "created_at": "1700000000",
    })
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch("api_server.routes.admin.get_redis", new_callable=AsyncMock, return_value=redis):
            resp = await client.get("/api/admin/jobs")
    assert resp.status_code == 200
    assert resp.json()["count"] == 1
