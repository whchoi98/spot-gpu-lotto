# Tests Module

## Role
pytest test suite with unit and integration tests. Uses fakeredis for unit tests
and testcontainers for integration tests.

## Structure
- `conftest.py` -- Shared fixtures (fakeredis async client, test settings)
- `unit/` -- Unit tests (fast, no external dependencies)
- `integration/` -- Integration tests (requires Redis via testcontainers)

## Unit Tests
- `test_auth.py` -- Auth middleware and JWT validation
- `test_capacity.py` -- Atomic GPU capacity management
- `test_collector.py` -- Spot price collector logic
- `test_config.py` -- Settings/config loading
- `test_models.py` -- Pydantic model validation
- `test_notifier.py` -- Job notification logic
- `test_pod_builder.py` -- Pod spec construction
- `test_reaper.py` -- Job reaper logic
- `test_region_selector.py` -- Cheapest region selection
- `test_agent_config.py` -- Agent config (dispatch_mode, agent_model, api_server_url)

## Integration Tests
- `test_api_admin.py` -- Admin API endpoints
- `test_api_health.py` -- Health check endpoints
- `test_api_jobs.py` -- Job CRUD via API
- `test_api_prices.py` -- Price query API
- `test_api_templates.py` -- Template CRUD API

## Rules
- `asyncio_mode = "auto"` in pyproject.toml (no need for `@pytest.mark.asyncio`)
- `pythonpath = ["src"]` -- imports use `from common.xxx import yyy`
- Unit tests use `fakeredis.aioredis` (in-memory, no real Redis needed)
- Integration tests use `testcontainers[redis]` (real Redis in Docker)
- Run: `pytest -v` (all), `pytest src/tests/unit/ -v` (unit only)
