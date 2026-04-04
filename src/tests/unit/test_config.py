import os
import pytest
from common.config import Settings


def test_default_settings():
    s = Settings(redis_url="redis://localhost:6379")
    assert s.regions == ["us-east-1", "us-east-2", "us-west-2"]
    assert s.instance_types == ["g6.xlarge", "g5.xlarge", "g6e.xlarge", "g6e.2xlarge", "g5.12xlarge", "g5.48xlarge"]
    assert s.poll_interval == 60
    assert s.reap_interval == 10
    assert s.job_timeout == 7200
    assert s.max_retries == 2
    assert s.capacity_per_region == 16
    assert s.auth_enabled is True
    assert s.k8s_mode == "live"
    assert s.price_mode == "live"


def test_settings_from_env(monkeypatch):
    monkeypatch.setenv("REDIS_URL", "redis://custom:6380")
    monkeypatch.setenv("REGIONS", '["us-west-2"]')
    monkeypatch.setenv("JOB_TIMEOUT", "3600")
    monkeypatch.setenv("AUTH_ENABLED", "false")
    monkeypatch.setenv("K8S_MODE", "dry-run")
    monkeypatch.setenv("PRICE_MODE", "mock")
    s = Settings()
    assert s.redis_url == "redis://custom:6380"
    assert s.regions == ["us-west-2"]
    assert s.job_timeout == 3600
    assert s.auth_enabled is False
    assert s.k8s_mode == "dry-run"
    assert s.price_mode == "mock"
