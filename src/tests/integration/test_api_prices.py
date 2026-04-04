from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from api_server.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def seeded_prices(redis):
    """Seed fake prices into Redis."""
    await redis.zadd("gpu:spot:prices", {
        "us-east-1:g6.xlarge": 0.36,
        "us-east-2:g6.xlarge": 0.23,
        "us-west-2:g6.xlarge": 0.44,
        "us-east-1:g5.xlarge": 0.38,
    })
    return redis


async def test_get_all_prices(client, seeded_prices):
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch(
            "api_server.routes.prices.get_redis",
            new_callable=AsyncMock,
            return_value=seeded_prices,
        ):
            resp = await client.get("/api/prices")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["prices"]) == 4


async def test_get_prices_filtered(client, seeded_prices):
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch(
            "api_server.routes.prices.get_redis",
            new_callable=AsyncMock,
            return_value=seeded_prices,
        ):
            resp = await client.get("/api/prices?instance_type=g6.xlarge")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["prices"]) == 3
    for p in data["prices"]:
        assert p["instance_type"] == "g6.xlarge"


async def test_get_prices_empty(client, redis):
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch(
            "api_server.routes.prices.get_redis",
            new_callable=AsyncMock,
            return_value=redis,
        ):
            resp = await client.get("/api/prices")
    assert resp.status_code == 200
    assert resp.json()["prices"] == []
