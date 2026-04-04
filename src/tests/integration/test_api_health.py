from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from api_server.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


async def test_healthz(client):
    resp = await client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


async def test_readyz_healthy(client):
    with patch("api_server.routes.health.redis_health", new_callable=AsyncMock, return_value=True):
        resp = await client.get("/readyz")
        assert resp.status_code == 200
        assert resp.json()["redis"] == "connected"


async def test_readyz_unhealthy(client):
    with patch("api_server.routes.health.redis_health", new_callable=AsyncMock, return_value=False):
        resp = await client.get("/readyz")
        assert resp.status_code == 200
        assert resp.json()["redis"] == "disconnected"
