# src/tests/conftest.py
import fakeredis.aioredis
import pytest


@pytest.fixture
async def redis():
    """Provide a clean fakeredis instance for each test."""
    r = fakeredis.aioredis.FakeRedis(decode_responses=True)
    yield r
    await r.flushall()
    await r.aclose()
