# AgentCore + Strands Agent Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Strands-based AI agent (deployed on AgentCore Runtime) that provides natural-language GPU job scheduling, using the existing dispatcher/price infrastructure as tools, with Gateway exposing the FastAPI endpoints as MCP tools for external agents.

**Architecture:** New `src/agent/` module wraps existing Redis-based price, capacity, and job functions as Strands `@tool` functions. A `BedrockAgentCoreApp` entrypoint receives natural-language prompts and delegates to a Strands `Agent` using `global.anthropic.claude-sonnet-4-6`. The existing rule-based dispatcher remains as fallback (configurable via `DISPATCH_MODE` env var: `"rule"` | `"agent"`).

**Tech Stack:** strands-agents, strands-agents-tools, bedrock-agentcore, fakeredis (test), pytest

---

## File Structure

```
src/
  agent/                      # NEW: Strands agent module
    __init__.py
    app.py                    # BedrockAgentCoreApp entrypoint
    tools.py                  # @tool functions wrapping existing logic
    system_prompt.py          # Agent system prompt
  common/
    config.py                 # MODIFY: add dispatch_mode, agent model settings
  dispatcher/
    queue_processor.py        # MODIFY: branch on dispatch_mode
  tests/
    unit/
      test_agent_tools.py     # NEW: unit tests for agent tools
```

---

### Task 1: Add Agent Config Settings

**Files:**
- Modify: `src/common/config.py:7-36`

- [ ] **Step 1: Write the failing test**

Create `src/tests/unit/test_agent_config.py`:

```python
import os
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_config.py -v`
Expected: FAIL — `Settings` has no `dispatch_mode` field

- [ ] **Step 3: Implement config changes**

In `src/common/config.py`, add these fields to the `Settings` class after the `price_mode` field (line 34):

```python
    # Agent
    dispatch_mode: str = "rule"  # "rule" or "agent"
    agent_model: str = "global.anthropic.claude-sonnet-4-6"
```

Add a `model_validator` to reject invalid `dispatch_mode` values. Add to imports:

```python
from pydantic import model_validator
```

Add validator inside `Settings`:

```python
    @model_validator(mode="after")
    def validate_dispatch_mode(self):
        if self.dispatch_mode not in ("rule", "agent"):
            raise ValueError(f"dispatch_mode must be 'rule' or 'agent', got '{self.dispatch_mode}'")
        return self
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_config.py -v`
Expected: 4 PASSED

- [ ] **Step 5: Ensure existing tests still pass**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_config.py -v`
Expected: All PASSED (no regressions)

- [ ] **Step 6: Commit**

```bash
git add src/common/config.py src/tests/unit/test_agent_config.py
git commit -m "feat(config): add dispatch_mode and agent_model settings"
```

---

### Task 2: Create Agent Tools — Price Lookup

**Files:**
- Create: `src/agent/__init__.py`
- Create: `src/agent/tools.py`
- Create: `src/tests/unit/test_agent_tools.py`

- [ ] **Step 1: Create module init**

Create `src/agent/__init__.py` (empty file):

```python
```

- [ ] **Step 2: Write the failing test for check_spot_prices**

Create `src/tests/unit/test_agent_tools.py`:

```python
import json
import pytest


@pytest.fixture
async def redis_with_prices(redis):
    """Seed Redis with spot prices and capacity."""
    await redis.zadd("gpu:spot:prices", {
        "us-east-2:g6.xlarge": 0.2261,
        "us-east-1:g6.xlarge": 0.3608,
        "us-west-2:g6.xlarge": 0.4402,
        "us-east-2:g5.xlarge": 0.2500,
    })
    await redis.set("gpu:capacity:us-east-1", "4")
    await redis.set("gpu:capacity:us-east-2", "4")
    await redis.set("gpu:capacity:us-west-2", "4")
    return redis


async def test_check_spot_prices_all(redis_with_prices):
    from agent.tools import check_spot_prices_impl

    result = json.loads(await check_spot_prices_impl(redis_with_prices))
    assert len(result) == 4
    # Sorted by price ascending
    assert result[0]["price"] == pytest.approx(0.2261)
    assert result[0]["region"] == "us-east-2"


async def test_check_spot_prices_filtered(redis_with_prices):
    from agent.tools import check_spot_prices_impl

    result = json.loads(
        await check_spot_prices_impl(redis_with_prices, instance_type="g5.xlarge")
    )
    assert len(result) == 1
    assert result[0]["instance_type"] == "g5.xlarge"


async def test_check_spot_prices_with_capacity(redis_with_prices):
    from agent.tools import check_spot_prices_impl

    await redis_with_prices.set("gpu:capacity:us-east-2", "0")
    result = json.loads(await check_spot_prices_impl(redis_with_prices))
    # us-east-2 entries should show capacity=0
    east2 = [r for r in result if r["region"] == "us-east-2"]
    assert east2[0]["available_capacity"] == 0
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_tools.py -v`
Expected: FAIL — `agent.tools` module not found

- [ ] **Step 4: Implement check_spot_prices_impl**

Create `src/agent/tools.py`:

```python
"""Strands @tool functions wrapping GPU Spot Lotto operations.

Each tool has an `_impl` async function (testable with fakeredis)
and a sync @tool wrapper that resolves the Redis dependency at call time.
"""
import json

import redis.asyncio as aioredis


async def check_spot_prices_impl(
    r: aioredis.Redis,
    instance_type: str | None = None,
    region: str | None = None,
) -> str:
    """Query current GPU Spot prices from Redis sorted set.

    Returns JSON array sorted by price ascending, each entry:
    {"region", "instance_type", "price", "available_capacity"}
    """
    all_prices = await r.zrange("gpu:spot:prices", 0, -1, withscores=True)
    results = []
    for member, score in all_prices:
        rgn, itype = member.rsplit(":", 1)
        if instance_type and itype != instance_type:
            continue
        if region and rgn != region:
            continue
        cap = await r.get(f"gpu:capacity:{rgn}")
        results.append({
            "region": rgn,
            "instance_type": itype,
            "price": round(score, 4),
            "available_capacity": int(cap) if cap else 0,
        })
    results.sort(key=lambda x: x["price"])
    return json.dumps(results)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_tools.py -v`
Expected: 3 PASSED

- [ ] **Step 6: Commit**

```bash
git add src/agent/__init__.py src/agent/tools.py src/tests/unit/test_agent_tools.py
git commit -m "feat(agent): add check_spot_prices tool with tests"
```

---

### Task 3: Create Agent Tools — Job Submission & Status

**Files:**
- Modify: `src/agent/tools.py`
- Modify: `src/tests/unit/test_agent_tools.py`

- [ ] **Step 1: Write failing tests for submit_job and get_job_status**

Append to `src/tests/unit/test_agent_tools.py`:

```python
async def test_submit_job(redis_with_prices):
    from agent.tools import submit_job_impl

    result = json.loads(await submit_job_impl(
        redis_with_prices,
        instance_type="g6.xlarge",
        image="nvidia/cuda:12.0-base",
        command="/bin/sh -c 'nvidia-smi'",
    ))
    assert result["status"] == "queued"
    # Verify job was pushed to Redis queue
    queue_len = await redis_with_prices.llen("gpu:job:queue")
    assert queue_len == 1


async def test_get_job_status_found(redis_with_prices):
    from agent.tools import get_job_status_impl

    await redis_with_prices.hset("gpu:jobs:test-123", mapping={
        "job_id": "test-123",
        "user_id": "user1",
        "region": "us-east-1",
        "status": "running",
        "pod_name": "gpu-job-test1234",
        "instance_type": "g6.xlarge",
        "created_at": "1700000000",
    })
    result = json.loads(await get_job_status_impl(redis_with_prices, "test-123"))
    assert result["status"] == "running"
    assert result["region"] == "us-east-1"


async def test_get_job_status_not_found(redis_with_prices):
    from agent.tools import get_job_status_impl

    result = json.loads(await get_job_status_impl(redis_with_prices, "nonexistent"))
    assert result["error"] == "job_not_found"


async def test_list_active_jobs(redis_with_prices):
    from agent.tools import list_active_jobs_impl

    await redis_with_prices.sadd("gpu:active_jobs", "job-1", "job-2")
    await redis_with_prices.hset("gpu:jobs:job-1", mapping={
        "job_id": "job-1", "user_id": "u1", "region": "us-east-1",
        "status": "running", "pod_name": "p1", "instance_type": "g6.xlarge",
        "created_at": "1700000000",
    })
    await redis_with_prices.hset("gpu:jobs:job-2", mapping={
        "job_id": "job-2", "user_id": "u2", "region": "us-west-2",
        "status": "running", "pod_name": "p2", "instance_type": "g5.xlarge",
        "created_at": "1700000100",
    })
    result = json.loads(await list_active_jobs_impl(redis_with_prices))
    assert len(result) == 2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_tools.py::test_submit_job -v`
Expected: FAIL — `submit_job_impl` not found

- [ ] **Step 3: Implement submit_job_impl, get_job_status_impl, list_active_jobs_impl**

Append to `src/agent/tools.py`:

```python
async def submit_job_impl(
    r: aioredis.Redis,
    instance_type: str = "g6.xlarge",
    image: str = "nvidia/cuda:12.0-base",
    command: str = "nvidia-smi && sleep 60",
    gpu_count: int = 1,
    checkpoint_enabled: bool = False,
) -> str:
    """Submit a GPU job to the dispatch queue.

    Returns JSON with {status: "queued"} on success.
    The dispatcher will pick this up and schedule it.
    """
    job = {
        "instance_type": instance_type,
        "image": image,
        "command": ["/bin/sh", "-c", command],
        "gpu_count": gpu_count,
        "checkpoint_enabled": checkpoint_enabled,
    }
    await r.lpush("gpu:job:queue", json.dumps(job))
    return json.dumps({"status": "queued", "instance_type": instance_type})


async def get_job_status_impl(r: aioredis.Redis, job_id: str) -> str:
    """Get the current status of a GPU job by its ID.

    Returns JSON with job details or {error: "job_not_found"}.
    """
    data = await r.hgetall(f"gpu:jobs:{job_id}")
    if not data:
        return json.dumps({"error": "job_not_found", "job_id": job_id})
    return json.dumps({
        "job_id": data.get("job_id"),
        "status": data.get("status"),
        "region": data.get("region"),
        "instance_type": data.get("instance_type"),
        "created_at": data.get("created_at"),
        "error_reason": data.get("error_reason"),
    })


async def list_active_jobs_impl(r: aioredis.Redis) -> str:
    """List all currently active GPU jobs.

    Returns JSON array of job summaries.
    """
    job_ids = await r.smembers("gpu:active_jobs")
    jobs = []
    for jid in sorted(job_ids):
        data = await r.hgetall(f"gpu:jobs:{jid}")
        if data:
            jobs.append({
                "job_id": data.get("job_id"),
                "status": data.get("status"),
                "region": data.get("region"),
                "instance_type": data.get("instance_type"),
            })
    return json.dumps(jobs)
```

- [ ] **Step 4: Run all agent tool tests**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_tools.py -v`
Expected: 7 PASSED

- [ ] **Step 5: Commit**

```bash
git add src/agent/tools.py src/tests/unit/test_agent_tools.py
git commit -m "feat(agent): add submit_job, get_job_status, list_active_jobs tools"
```

---

### Task 4: Create Agent Tools — Failure History

**Files:**
- Modify: `src/agent/tools.py`
- Modify: `src/tests/unit/test_agent_tools.py`

- [ ] **Step 1: Write failing test for get_failure_history**

Append to `src/tests/unit/test_agent_tools.py`:

```python
async def test_failure_history(redis_with_prices):
    from agent.tools import get_failure_history_impl

    # Seed some finished failed jobs
    for i, region in enumerate(["us-east-1", "us-east-1", "us-west-2"]):
        await redis_with_prices.hset(f"gpu:jobs:fail-{i}", mapping={
            "job_id": f"fail-{i}", "user_id": "u1", "region": region,
            "status": "failed", "pod_name": f"p{i}", "instance_type": "g6.xlarge",
            "created_at": str(1700000000 + i),
            "finished_at": str(1700000100 + i),
            "error_reason": "preempted" if region == "us-east-1" else "timeout",
        })
        await redis_with_prices.sadd("gpu:finished_jobs", f"fail-{i}")

    result = json.loads(await get_failure_history_impl(redis_with_prices))
    assert result["total_failures"] == 3
    assert result["by_region"]["us-east-1"] == 2
    assert result["by_reason"]["preempted"] == 2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_tools.py::test_failure_history -v`
Expected: FAIL — `get_failure_history_impl` not found

- [ ] **Step 3: Implement get_failure_history_impl**

Append to `src/agent/tools.py`:

```python
async def get_failure_history_impl(r: aioredis.Redis) -> str:
    """Analyze recent job failure patterns by region and error reason.

    Returns JSON with failure counts grouped by region and by reason.
    The agent uses this to avoid regions with high preemption rates.
    """
    job_ids = await r.smembers("gpu:finished_jobs")
    by_region: dict[str, int] = {}
    by_reason: dict[str, int] = {}
    total = 0
    for jid in job_ids:
        data = await r.hgetall(f"gpu:jobs:{jid}")
        if data.get("status") == "failed":
            total += 1
            rgn = data.get("region", "unknown")
            reason = data.get("error_reason", "unknown")
            by_region[rgn] = by_region.get(rgn, 0) + 1
            by_reason[reason] = by_reason.get(reason, 0) + 1
    return json.dumps({
        "total_failures": total,
        "by_region": by_region,
        "by_reason": by_reason,
    })
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_tools.py -v`
Expected: 8 PASSED

- [ ] **Step 5: Commit**

```bash
git add src/agent/tools.py src/tests/unit/test_agent_tools.py
git commit -m "feat(agent): add failure history analysis tool"
```

---

### Task 5: Create Strands @tool Wrappers

**Files:**
- Modify: `src/agent/tools.py`

- [ ] **Step 1: Add Strands @tool wrappers**

Add at the top of `src/agent/tools.py`, after existing imports:

```python
import asyncio

from strands import tool

from common.redis_client import get_redis
```

Then add the sync `@tool` wrappers at the bottom of the file:

```python
def _run(coro):
    """Run async function from sync @tool context."""
    loop = asyncio.get_event_loop()
    if loop.is_running():
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor() as pool:
            return pool.submit(asyncio.run, coro).result()
    return loop.run_until_complete(coro)


@tool
def check_spot_prices(
    instance_type: str = "",
    region: str = "",
) -> str:
    """Check current GPU Spot instance prices across all regions.

    Args:
        instance_type: Filter by instance type (e.g. "g6.xlarge"). Empty for all.
        region: Filter by region (e.g. "us-east-1"). Empty for all.

    Returns:
        JSON array of prices sorted cheapest first, with available capacity per region.
    """
    async def _run_query():
        r = await get_redis()
        return await check_spot_prices_impl(
            r,
            instance_type=instance_type or None,
            region=region or None,
        )
    return _run(_run_query())


@tool
def submit_gpu_job(
    instance_type: str,
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
    async def _run_submit():
        r = await get_redis()
        return await submit_job_impl(r, instance_type, image, command, gpu_count, checkpoint_enabled)
    return _run(_run_submit())


@tool
def get_job_status(job_id: str) -> str:
    """Get the current status of a GPU job.

    Args:
        job_id: The UUID of the job to check.

    Returns:
        JSON with job status, region, instance type, and error info if failed.
    """
    async def _run_status():
        r = await get_redis()
        return await get_job_status_impl(r, job_id)
    return _run(_run_status())


@tool
def list_active_jobs() -> str:
    """List all currently running GPU jobs.

    Returns:
        JSON array of active job summaries with status, region, and instance type.
    """
    async def _run_list():
        r = await get_redis()
        return await list_active_jobs_impl(r)
    return _run(_run_list())


@tool
def get_failure_history() -> str:
    """Analyze recent job failure patterns to identify unstable regions.

    Returns:
        JSON with failure counts grouped by region and by error reason.
        Use this to avoid regions with high preemption or failure rates.
    """
    async def _run_history():
        r = await get_redis()
        return await get_failure_history_impl(r)
    return _run(_run_history())
```

- [ ] **Step 2: Verify existing tests still pass**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_tools.py -v`
Expected: 8 PASSED (wrappers don't break `_impl` functions)

- [ ] **Step 3: Commit**

```bash
git add src/agent/tools.py
git commit -m "feat(agent): add Strands @tool wrappers for all agent tools"
```

---

### Task 6: Create System Prompt and Agent App

**Files:**
- Create: `src/agent/system_prompt.py`
- Create: `src/agent/app.py`

- [ ] **Step 1: Create system prompt**

Create `src/agent/system_prompt.py`:

```python
"""System prompt for the GPU Spot Lotto scheduling agent."""

SYSTEM_PROMPT = """You are a GPU Spot instance scheduling agent for GPU Spot Lotto.
You help users submit GPU training and inference jobs at the lowest possible cost
across multiple AWS regions (us-east-1, us-east-2, us-west-2).

Your responsibilities:
1. Check current Spot prices and available capacity before recommending a region.
2. Consider failure history — avoid regions with recent preemption spikes.
3. Submit jobs to the scheduling queue when the user requests it.
4. Monitor job status and report results.

Decision-making guidelines:
- Prefer regions with the lowest price AND available capacity > 0.
- If the cheapest region has 2+ recent failures from preemption, recommend the next
  cheapest region and explain why.
- If no region has capacity, tell the user and suggest waiting or trying a different
  instance type.
- When the user specifies VRAM requirements instead of instance types, map them:
  - L4 (24GB): g6.xlarge
  - A10G (24GB): g5.xlarge
  - A10G x4 (96GB): g5.12xlarge
  - A10G x8 (192GB): g5.48xlarge
  - L40S (48GB): g6e.xlarge
  - L40S x2 (96GB): g6e.2xlarge

Always respond in the same language the user uses (Korean or English).
Always show prices in USD per hour.
"""
```

- [ ] **Step 2: Create the BedrockAgentCoreApp entrypoint**

Create `src/agent/app.py`:

```python
"""BedrockAgentCore entrypoint for the GPU Spot Lotto agent."""
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent

from agent.system_prompt import SYSTEM_PROMPT
from agent.tools import (
    check_spot_prices,
    get_failure_history,
    get_job_status,
    list_active_jobs,
    submit_gpu_job,
)
from common.config import get_settings

app = BedrockAgentCoreApp()

TOOLS = [check_spot_prices, submit_gpu_job, get_job_status, list_active_jobs, get_failure_history]


def create_agent() -> Agent:
    settings = get_settings()
    return Agent(
        model=settings.agent_model,
        tools=TOOLS,
        system_prompt=SYSTEM_PROMPT,
    )


@app.entrypoint
def invoke(payload, context):
    """Handle an incoming agent invocation."""
    prompt = payload.get(
        "prompt",
        "No prompt provided. Ask the user what GPU job they'd like to run.",
    )
    agent = create_agent()
    result = agent(prompt)
    return {"result": result.message}


if __name__ == "__main__":
    app.run()
```

- [ ] **Step 3: Commit**

```bash
git add src/agent/system_prompt.py src/agent/app.py
git commit -m "feat(agent): add Strands agent app with system prompt"
```

---

### Task 7: Create Agent CLAUDE.md

**Files:**
- Create: `src/agent/CLAUDE.md`

Per project convention (new directory under `src/` must have a `CLAUDE.md`).

- [ ] **Step 1: Create the module docs**

Create `src/agent/CLAUDE.md`:

```markdown
# Agent Module

## Role
Strands-based AI agent deployed on AgentCore Runtime.
Provides natural-language interface for GPU Spot job scheduling.
Uses `global.anthropic.claude-sonnet-4-6` as the LLM.

## Key Files
- `app.py` -- BedrockAgentCoreApp entrypoint, creates Strands Agent
- `tools.py` -- @tool functions: check_spot_prices, submit_gpu_job, get_job_status, list_active_jobs, get_failure_history
- `system_prompt.py` -- Agent system prompt with GPU instance mapping and decision guidelines

## Architecture
- Each tool has an `_impl` async function (testable with fakeredis) and a sync `@tool` wrapper
- `_impl` functions take a Redis connection as first argument for dependency injection in tests
- `@tool` wrappers resolve Redis via `get_redis()` at call time

## Rules
- Model is fixed to `global.anthropic.claude-sonnet-4-6` (configurable via AGENT_MODEL env var)
- `dispatch_mode` setting controls whether the regular dispatcher uses rule-based or agent logic
- Tools return JSON strings (Strands convention)
- The agent responds in the same language as the user (Korean/English)
```

- [ ] **Step 2: Commit**

```bash
git add src/agent/CLAUDE.md
git commit -m "docs(agent): add CLAUDE.md for agent module"
```

---

### Task 8: Wire Agent Mode into Dispatcher (Optional Path)

**Files:**
- Modify: `src/dispatcher/queue_processor.py:20-75`

- [ ] **Step 1: Write failing test for agent dispatch mode**

Create `src/tests/unit/test_agent_dispatch.py`:

```python
import json
import pytest
from unittest.mock import patch, MagicMock


@pytest.fixture
async def redis_with_job(redis):
    """Seed Redis for dispatch test."""
    await redis.zadd("gpu:spot:prices", {"us-east-2:g6.xlarge": 0.2261})
    await redis.set("gpu:capacity:us-east-2", "4")
    return redis


async def test_rule_mode_dispatches_normally(redis_with_job):
    """In rule mode, process_one_job uses existing select_region logic."""
    from dispatcher.queue_processor import process_one_job

    job_json = json.dumps({"instance_type": "g6.xlarge", "image": "nvidia/cuda:12.0-base"})
    with patch("dispatcher.queue_processor.get_settings") as mock_settings:
        s = MagicMock()
        s.k8s_mode = "dry-run"
        s.max_retries = 2
        s.dispatch_mode = "rule"
        mock_settings.return_value = s
        result = await process_one_job(redis_with_job, job_json)
    assert result["status"] == "running"
    assert result["region"] == "us-east-2"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_dispatch.py -v`
Expected: FAIL — `Settings` mock may not have `dispatch_mode` or test may error on missing attribute

- [ ] **Step 3: Add dispatch_mode branch to queue_processor**

In `src/dispatcher/queue_processor.py`, the `process_one_job` function stays unchanged for `dispatch_mode="rule"` (the current default). No changes needed because `dispatch_mode="agent"` means the Strands agent handles scheduling directly through its own tools — the BRPOP dispatcher is only used in rule mode.

Add a check at the top of `process_queue` to log the active mode:

```python
async def process_queue(r: aioredis.Redis) -> None:
    """Main BRPOP loop — runs forever."""
    settings = get_settings()
    log.info("queue_processor_started", dispatch_mode=settings.dispatch_mode)
    if settings.dispatch_mode == "agent":
        log.info("agent_mode_active", msg="Jobs are handled by AgentCore agent. Queue processor idle.")
        # In agent mode, the queue is consumed by the Strands agent tools.
        # The BRPOP loop still runs as a fallback for jobs submitted directly to Redis.
    while True:
        queue_len = await r.llen("gpu:job:queue")
        QUEUE_DEPTH.set(queue_len)
        item = await r.brpop("gpu:job:queue", timeout=5)
        if item:
            _, job_json = item
            try:
                result = await process_one_job(r, job_json)
                log.info("job_processed", result=result)
            except Exception as e:
                log.error("job_processing_error", error=str(e))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/test_agent_dispatch.py -v`
Expected: PASSED

- [ ] **Step 5: Ensure all existing tests still pass**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/ -v`
Expected: All PASSED

- [ ] **Step 6: Commit**

```bash
git add src/dispatcher/queue_processor.py src/tests/unit/test_agent_dispatch.py
git commit -m "feat(dispatcher): log dispatch_mode, support agent mode awareness"
```

---

### Task 9: Add AgentCore Deployment Config

**Files:**
- Create: `.bedrock_agentcore.yaml` (root)
- Create: `requirements-agent.txt`

- [ ] **Step 1: Create requirements file for agent deployment**

Create `requirements-agent.txt`:

```
bedrock-agentcore
strands-agents
strands-agents-tools
redis
pydantic
pydantic-settings
httpx
structlog
```

- [ ] **Step 2: Create AgentCore config**

Create `.bedrock_agentcore.yaml`:

```yaml
# AgentCore deployment configuration for GPU Spot Lotto Agent
agent_name: gpu-spot-lotto-agent
entrypoint: src/agent/app.py
runtime: PYTHON_3_11
requirements_file: requirements-agent.txt
deployment_type: direct_code_deploy
region: ap-northeast-2
protocol: HTTP
disable_otel: false
disable_memory: true
```

- [ ] **Step 3: Commit**

```bash
git add .bedrock_agentcore.yaml requirements-agent.txt
git commit -m "feat(agent): add AgentCore deployment config and requirements"
```

---

### Task 10: Run Full Test Suite and Verify

- [ ] **Step 1: Run all unit tests**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && python -m pytest src/tests/unit/ -v`
Expected: All PASSED, including new test files:
- `test_agent_config.py` (4 tests)
- `test_agent_tools.py` (8 tests)
- `test_agent_dispatch.py` (1 test)

- [ ] **Step 2: Run ruff linter**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && ruff check src/agent/`
Expected: No errors

- [ ] **Step 3: Run mypy type check**

Run: `cd /home/ec2-user/my-project/spot-gpu-lotto && mypy src/agent/`
Expected: No errors (or only strands-related missing stubs)

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -u
git commit -m "fix: lint and type fixes for agent module"
```
