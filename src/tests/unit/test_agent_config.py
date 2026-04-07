import pytest
from common.config import Settings


def test_default_dispatch_mode():
    s = Settings(redis_url="redis://localhost:6379")
    assert s.dispatch_mode == "rule"


def test_agent_dispatch_mode():
    s = Settings(redis_url="redis://localhost:6379", dispatch_mode="agent")
    assert s.dispatch_mode == "agent"


def test_agent_model_default():
    s = Settings(redis_url="redis://localhost:6379")
    assert s.agent_model == "global.anthropic.claude-sonnet-4-6"


def test_invalid_dispatch_mode():
    with pytest.raises(Exception):
        Settings(redis_url="redis://localhost:6379", dispatch_mode="invalid")
