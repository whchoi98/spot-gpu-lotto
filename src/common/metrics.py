"""Prometheus metrics definitions for GPU Spot Lotto."""
from prometheus_client import Counter, Gauge, Histogram

# API Server
JOBS_SUBMITTED = Counter(
    "gpu_lotto_jobs_submitted_total",
    "Total jobs submitted",
)
JOBS_ACTIVE = Gauge(
    "gpu_lotto_jobs_active",
    "Currently active jobs",
)
API_REQUEST_DURATION = Histogram(
    "gpu_lotto_api_request_duration_seconds",
    "API request duration",
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)

# Dispatcher
JOBS_DISPATCHED = Counter(
    "gpu_lotto_jobs_dispatched_total",
    "Total jobs dispatched",
    ["region"],
)
JOBS_FAILED = Counter(
    "gpu_lotto_jobs_failed_total",
    "Total jobs failed",
    ["reason"],
)
JOBS_RETRIED = Counter(
    "gpu_lotto_jobs_retried_total",
    "Total jobs retried",
)
QUEUE_DEPTH = Gauge(
    "gpu_lotto_queue_depth",
    "Current job queue depth",
)
REGION_CAPACITY = Gauge(
    "gpu_lotto_region_capacity",
    "Available GPU capacity per region",
    ["region"],
)
JOB_DURATION = Histogram(
    "gpu_lotto_job_duration_seconds",
    "Job execution duration",
    buckets=[10, 30, 60, 300, 600, 1800, 3600, 7200],
)

# Price Watcher
SPOT_PRICE = Gauge(
    "gpu_lotto_spot_price",
    "Current Spot price",
    ["region", "instance_type"],
)
PRICE_FETCH_ERRORS = Counter(
    "gpu_lotto_price_fetch_errors_total",
    "Price fetch errors",
)
