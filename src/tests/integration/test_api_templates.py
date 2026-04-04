import pytest
from unittest.mock import patch, AsyncMock
from httpx import AsyncClient, ASGITransport
from api_server.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


async def test_template_crud(client, redis):
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch("api_server.routes.templates.get_redis", new_callable=AsyncMock, return_value=redis):
            # Save
            resp = await client.post("/api/templates", json={
                "name": "Test Template",
                "image": "test:v1",
                "instance_type": "g6.xlarge",
                "gpu_count": 1,
                "storage_mode": "s3",
                "command": ["python", "run.py"],
            })
            assert resp.status_code == 200
            assert resp.json()["name"] == "Test Template"

            # List
            resp = await client.get("/api/templates")
            assert resp.status_code == 200
            templates = resp.json()["templates"]
            assert len(templates) == 1
            assert templates[0]["name"] == "Test Template"

            # Delete
            resp = await client.delete("/api/templates/Test Template")
            assert resp.status_code == 200

            # List again (empty)
            resp = await client.get("/api/templates")
            assert len(resp.json()["templates"]) == 0


async def test_delete_nonexistent_template(client, redis):
    with patch("api_server.auth.get_settings") as mock_s:
        mock_s.return_value.auth_enabled = False
        with patch("api_server.routes.templates.get_redis", new_callable=AsyncMock, return_value=redis):
            resp = await client.delete("/api/templates/nope")
    assert resp.status_code == 404
