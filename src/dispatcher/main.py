"""Dispatcher entrypoint — runs queue processor and reaper concurrently."""
from __future__ import annotations

import asyncio

from prometheus_client import start_http_server

from common.config import get_settings
from common.k8s_client import get_k8s_client
from common.logging import get_logger, setup_logging
from common.redis_client import close_redis, get_redis
from dispatcher.capacity import init_capacity
from dispatcher.queue_processor import process_queue
from dispatcher.reaper import reap_job

log = get_logger("dispatcher")


async def reap_loop(r) -> None:
    """Periodically reap completed/failed jobs."""
    settings = get_settings()

    def _get_pod_phase(region: str, pod_name: str) -> str | None:
        if settings.k8s_mode == "dry-run":
            return None
        try:
            k8s = get_k8s_client(region)
            pod = k8s.read_namespaced_pod(name=pod_name, namespace="gpu-jobs")
            return pod.status.phase
        except Exception as e:
            log.warning("pod_read_error", region=region, pod_name=pod_name, error=str(e))
            return None

    def _delete_pod(region: str, pod_name: str) -> bool:
        if settings.k8s_mode == "dry-run":
            log.info("dry_run_pod_delete", region=region, pod_name=pod_name)
            return True
        try:
            k8s = get_k8s_client(region)
            k8s.delete_namespaced_pod(name=pod_name, namespace="gpu-jobs")
            return True
        except Exception as e:
            log.error("pod_delete_error", region=region, pod_name=pod_name, error=str(e))
            return False

    while True:
        active_jobs = await r.smembers("gpu:active_jobs")
        for job_id in active_jobs:
            await reap_job(r, job_id, _get_pod_phase, _delete_pod)
        await asyncio.sleep(settings.reap_interval)


async def main() -> None:
    setup_logging()
    try:
        start_http_server(9090)
    except OSError as e:
        log.warning("metrics_server_failed", port=9090, error=str(e))
    settings = get_settings()
    r = await get_redis()

    # Initialize capacity
    await init_capacity(r, settings.regions, settings.capacity_per_region)
    log.info("dispatcher_started", regions=settings.regions, k8s_mode=settings.k8s_mode)

    try:
        await asyncio.gather(process_queue(r), reap_loop(r))
    finally:
        await close_redis()


if __name__ == "__main__":
    asyncio.run(main())
