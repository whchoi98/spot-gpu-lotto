"""Application settings loaded from environment variables."""
from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Redis
    redis_url: str = "redis://localhost:6379"

    # Regions & instance types
    regions: list[str] = ["us-east-1", "us-east-2", "us-west-2"]
    instance_types: list[str] = [
        "g6.xlarge", "g5.xlarge",
        "g6e.xlarge", "g6e.2xlarge",
        "g5.12xlarge", "g5.48xlarge",
    ]

    # Timing
    poll_interval: int = 60
    reap_interval: int = 10
    job_timeout: int = 7200

    # Retry
    max_retries: int = 2
    capacity_per_region: int = 16

    # Feature flags
    auth_enabled: bool = True
    k8s_mode: str = "live"       # "live" or "dry-run"
    price_mode: str = "live"     # "live" or "mock"

    model_config = {"env_prefix": "", "case_sensitive": False}


@lru_cache
def get_settings() -> Settings:
    return Settings()
