"""Shared data models for GPU Spot Lotto."""
from enum import StrEnum

from pydantic import BaseModel


class JobStatus(StrEnum):
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    CANCELLING = "cancelling"
    CANCELLED = "cancelled"


class JobRequest(BaseModel):
    user_id: str
    image: str = "nvidia/cuda:12.0-base"
    command: list[str] = ["/bin/sh", "-c", "nvidia-smi && sleep 60"]
    instance_type: str = "g6.xlarge"
    gpu_type: str = "l4"
    gpu_count: int = 1
    storage_mode: str = "s3"
    checkpoint_enabled: bool = False
    webhook_url: str | None = None


class JobRecord(BaseModel):
    job_id: str
    user_id: str
    region: str
    status: JobStatus
    pod_name: str
    instance_type: str
    created_at: int
    finished_at: int | None = None
    retry_count: int = 0
    checkpoint_enabled: bool = False
    webhook_url: str | None = None
    result_path: str | None = None
    error_reason: str | None = None

    def to_redis(self) -> dict[str, str]:
        d: dict[str, str] = {}
        for k, v in self.model_dump().items():
            if v is not None:
                d[k] = str(v) if not isinstance(v, str) else v
        return d

    @classmethod
    def from_redis(cls, data: dict[str, str]) -> "JobRecord":
        return cls(
            job_id=data["job_id"],
            user_id=data["user_id"],
            region=data["region"],
            status=JobStatus(data["status"]),
            pod_name=data["pod_name"],
            instance_type=data["instance_type"],
            created_at=int(data["created_at"]),
            finished_at=int(data["finished_at"]) if data.get("finished_at") else None,
            retry_count=int(data.get("retry_count", "0")),
            checkpoint_enabled=data.get("checkpoint_enabled", "False").lower() == "true",
            webhook_url=data.get("webhook_url"),
            result_path=data.get("result_path"),
            error_reason=data.get("error_reason"),
        )


class PriceEntry(BaseModel):
    region: str
    instance_type: str
    price: float

    @property
    def redis_key(self) -> str:
        return f"{self.region}:{self.instance_type}"


class TemplateEntry(BaseModel):
    name: str
    image: str
    instance_type: str = "g6.xlarge"
    gpu_count: int = 1
    gpu_type: str = "l4"
    storage_mode: str = "s3"
    checkpoint_enabled: bool = False
    command: list[str] = ["/bin/sh", "-c", "nvidia-smi && sleep 60"]
