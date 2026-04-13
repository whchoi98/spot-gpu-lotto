# API Server Module

## Role
FastAPI application serving the REST API for GPU Spot Lotto.
Handles job submission, status queries, price data, admin operations, and SSE streaming.
Auth: Cognito JWT in prod, hardcoded `dev-user/admin` when `AUTH_ENABLED=false`.

## Endpoints

### Jobs (`routes/jobs.py`, prefix `/api`)
- `POST /api/jobs` -- Submit GPU job to Redis queue (no job_id returned; dispatcher generates it)
- `GET /api/jobs/{job_id}` -- Get job status from Redis hash
- `DELETE /api/jobs/{job_id}` -- Cancel a running job
- `GET /api/jobs/{job_id}/stream` -- SSE stream for real-time status updates
- `PUT /api/settings/webhook` -- Save user webhook URL

### Prices (`routes/prices.py`, prefix `/api`)
- `GET /api/prices` -- Current spot prices (from Redis sorted set)

### Upload (`routes/upload.py`, prefix `/api`)
- `POST /api/upload/presign` -- Generate S3 presigned upload URL

### Templates (`routes/templates.py`, prefix `/api`)
- `GET /api/templates` -- List job templates
- `POST /api/templates` -- Create/save a template
- `DELETE /api/templates/{name}` -- Delete a template

### Admin (`routes/admin.py`, prefix `/api/admin`)
- `GET /api/admin/jobs` -- List all active jobs (admin only)
- `DELETE /api/admin/jobs/{job_id}` -- Force-delete a job
- `POST /api/admin/jobs/{job_id}/retry` -- Retry a failed job
- `GET /api/admin/regions` -- List regions with capacity
- `PUT /api/admin/regions/{region}/capacity` -- Update region capacity
- `GET /api/admin/stats` -- Active job count + queue depth

### Agent (`routes/agent.py`, prefix `/api/agent`)
- `POST /api/agent/chat` -- AI chat (Bedrock Converse API + Redis context, hybrid approval model)

### Health (`routes/health.py`)
- `GET /healthz` -- Liveness probe
- `GET /readyz` -- Readiness probe (checks Redis)

### Metrics (`main.py`)
- `GET /metrics` -- Prometheus metrics export

## Key Files
- `main.py` -- FastAPI app, CORS, router registration, `/metrics` endpoint
- `auth.py` -- JWT validation, `get_current_user` / `require_admin` dependencies
- `routes/jobs.py` -- Job CRUD + SSE streaming
- `routes/prices.py` -- Price query endpoints
- `routes/admin.py` -- Admin-only endpoints
- `routes/agent.py` -- AI agent chat (Bedrock Converse + Redis context)
- `routes/templates.py` -- Job template CRUD
- `routes/upload.py` -- S3 presigned URL generation
- `routes/health.py` -- Liveness and readiness probes

## Rules
- Pydantic model validation runs BEFORE FastAPI dependency injection (auth)
- Request body fields must be optional if they're overridden by middleware
- All Redis operations are async (`await r.xxx()`)
- `dict.get("key") or default` pattern for handling None values in Redis data
