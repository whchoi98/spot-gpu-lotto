"""Job management tools — httpx calls to API Server (single data path).

All job operations go through the API Server. No direct Redis access.
"""
import httpx
from strands import tool

from common.config import get_settings

API_TIMEOUT = 10.0


def _api_url() -> str:
    """Resolve API Server base URL."""
    settings = get_settings()
    return settings.api_server_url


@tool
def get_prices(instance_type: str = "", region: str = "") -> str:
    """Check current GPU Spot instance prices across all regions.

    Args:
        instance_type: Filter by instance type (e.g. "g6.xlarge"). Empty for all.
        region: Filter by region (e.g. "us-east-1"). Empty for all.

    Returns:
        JSON with spot prices sorted cheapest first, with available capacity per region.
    """
    params = {}
    if instance_type:
        params["instance_type"] = instance_type
    if region:
        params["region"] = region
    resp = httpx.get(f"{_api_url()}/api/prices", params=params, timeout=API_TIMEOUT)
    return resp.text


@tool
def submit_job(
    instance_type: str = "g6.xlarge",
    image: str = "nvidia/cuda:12.0-base",
    command: str = "nvidia-smi && sleep 60",
    gpu_count: int = 1,
    checkpoint_enabled: bool = False,
) -> str:
    """Submit a GPU training/inference job to the scheduling queue.

    Args:
        instance_type: EC2 instance type (e.g. "g6.xlarge", "g5.12xlarge").
        image: Docker image to run.
        command: Shell command to execute inside the container.
        gpu_count: Number of GPUs required.
        checkpoint_enabled: Whether to enable checkpointing.

    Returns:
        JSON confirmation with queued status.
    """
    payload = {
        "instance_type": instance_type,
        "image": image,
        "command": ["/bin/sh", "-c", command],
        "gpu_count": gpu_count,
        "checkpoint_enabled": checkpoint_enabled,
    }
    resp = httpx.post(f"{_api_url()}/api/jobs", json=payload, timeout=API_TIMEOUT)
    return resp.text


@tool
def get_job_status(job_id: str) -> str:
    """Get the current status of a GPU job.

    Args:
        job_id: The UUID of the job to check.

    Returns:
        JSON with job status, region, instance type, and error info if failed.
    """
    resp = httpx.get(f"{_api_url()}/api/jobs/{job_id}", timeout=API_TIMEOUT)
    return resp.text


@tool
def cancel_job(job_id: str) -> str:
    """Cancel a running GPU job.

    Args:
        job_id: The UUID of the job to cancel.

    Returns:
        JSON confirmation of cancellation.
    """
    resp = httpx.delete(f"{_api_url()}/api/jobs/{job_id}", timeout=API_TIMEOUT)
    return resp.text


@tool
def list_jobs() -> str:
    """List all currently active GPU jobs.

    Returns:
        JSON array of active job summaries with status, region, and instance type.
    """
    resp = httpx.get(f"{_api_url()}/api/admin/jobs", timeout=API_TIMEOUT)
    return resp.text


@tool
def get_stats() -> str:
    """Get system statistics including active job count and queue depth.

    Returns:
        JSON with active_jobs count and queue_depth.
    """
    resp = httpx.get(f"{_api_url()}/api/admin/stats", timeout=API_TIMEOUT)
    return resp.text
