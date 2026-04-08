# Common Module

## Role
Shared utilities, models, configuration, and client factories used by all services
(api_server, dispatcher, price_watcher).

## Key Files
- `config.py` -- `Settings` class via pydantic-settings (env vars: REDIS_URL, K8S_MODE, DISPATCH_MODE, AGENT_MODEL, etc.)
- `models.py` -- Pydantic models: `JobRequest`, `JobRecord`, `JobStatus` enum
- `redis_client.py` -- Async Redis connection factory (singleton)
- `k8s_client.py` -- Kubernetes client factory per region (uses `aws eks get-token`)
- `logging.py` -- structlog JSON logger setup
- `metrics.py` -- Prometheus counters/gauges (JOBS_DISPATCHED, QUEUE_DEPTH, etc.)

## Redis Key Structure
- `gpu:spot:prices` -- Sorted set: `{region}:{instance_type}` scored by price
- `gpu:job:queue` -- List: job payloads (BRPOP by dispatcher)
- `gpu:jobs:{job_id}` -- Hash: job record fields
- `gpu:active_jobs` -- Set: currently active job IDs
- `gpu:jobs:{job_id}:status` -- Pub/Sub channel for SSE streaming
- `gpu:user:{user_id}:webhook` -- String: user's webhook URL

## Rules
- All models use `str | None = None` for optional fields (not `Optional[str]`)
- `k8s_client.py` shells out to `aws eks get-token` -- requires AWS CLI in container
- Settings are cached via `@lru_cache` on `get_settings()`
