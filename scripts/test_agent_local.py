"""Local test script for the Strands agent tools.

Tests all _impl functions against fakeredis with mock data,
then tests the Strands Agent with tool invocations (requires AWS credentials
for Bedrock model access).

Usage:
    # Test tools only (no AWS creds needed):
    .venv/bin/python scripts/test_agent_local.py --tools-only

    # Full agent test (needs AWS creds + Bedrock model access):
    .venv/bin/python scripts/test_agent_local.py
"""
import argparse
import asyncio
import json
import sys

sys.path.insert(0, "src")


async def seed_redis(r):
    """Seed fakeredis with realistic mock data."""
    await r.zadd("gpu:spot:prices", {
        "us-east-1:g6.xlarge": 0.3608,
        "us-east-2:g6.xlarge": 0.2261,
        "us-west-2:g6.xlarge": 0.4402,
        "us-east-1:g5.xlarge": 0.3800,
        "us-east-2:g5.xlarge": 0.2500,
        "us-west-2:g5.xlarge": 0.4100,
        "us-east-1:g5.12xlarge": 2.80,
        "us-east-2:g5.12xlarge": 2.50,
        "us-west-2:g5.12xlarge": 3.10,
    })
    await r.set("gpu:capacity:us-east-1", "4")
    await r.set("gpu:capacity:us-east-2", "8")
    await r.set("gpu:capacity:us-west-2", "2")

    for i, (region, reason) in enumerate([
        ("us-east-1", "preempted"),
        ("us-east-1", "preempted"),
        ("us-east-1", "preempted"),
        ("us-west-2", "timeout"),
        ("us-east-2", "oom"),
    ]):
        await r.hset(f"gpu:jobs:fail-{i}", mapping={
            "job_id": f"fail-{i}",
            "user_id": "test-user",
            "region": region,
            "status": "failed",
            "pod_name": f"gpu-job-fail{i}",
            "instance_type": "g6.xlarge",
            "created_at": str(1700000000 + i),
            "finished_at": str(1700000300 + i),
            "error_reason": reason,
        })
        await r.sadd("gpu:finished_jobs", f"fail-{i}")

    await r.hset("gpu:jobs:active-001", mapping={
        "job_id": "active-001",
        "user_id": "test-user",
        "region": "us-east-2",
        "status": "running",
        "pod_name": "gpu-job-active00",
        "instance_type": "g6.xlarge",
        "created_at": "1700001000",
    })
    await r.sadd("gpu:active_jobs", "active-001")
    print("[OK] Redis seeded with mock data")


async def test_tools(r):
    """Test all _impl functions."""
    from agent.tools import (
        check_spot_prices_impl,
        get_failure_history_impl,
        get_job_status_impl,
        list_active_jobs_impl,
        submit_job_impl,
    )

    print("\n=== Tool Tests ===\n")

    result = json.loads(await check_spot_prices_impl(r))
    print(f"[check_spot_prices] All prices ({len(result)} entries):")
    for p in result[:5]:
        print(f"  {p['region']:12s} {p['instance_type']:14s} ${p['price']:.4f}/hr  (cap={p['available_capacity']})")
    if len(result) > 5:
        print(f"  ... and {len(result) - 5} more")

    result = json.loads(await check_spot_prices_impl(r, instance_type="g5.12xlarge"))
    print(f"\n[check_spot_prices] g5.12xlarge only ({len(result)} entries):")
    for p in result:
        print(f"  {p['region']:12s} ${p['price']:.2f}/hr  cap={p['available_capacity']}")

    result = json.loads(await submit_job_impl(
        r, instance_type="g6.xlarge", image="my-training:v1",
        command="python train.py --epochs 10",
    ))
    print(f"\n[submit_job] Result: {result}")
    print(f"  Queue depth: {await r.llen('gpu:job:queue')}")

    result = json.loads(await list_active_jobs_impl(r))
    print(f"\n[list_active_jobs] {len(result)} active job(s):")
    for j in result:
        print(f"  {j['job_id']}  status={j['status']}  region={j['region']}")

    result = json.loads(await get_job_status_impl(r, "active-001"))
    print(f"\n[get_job_status] active-001: status={result['status']}, region={result['region']}")

    result = json.loads(await get_job_status_impl(r, "nonexistent"))
    print(f"[get_job_status] nonexistent: {result}")

    result = json.loads(await get_failure_history_impl(r))
    print(f"\n[get_failure_history] {result['total_failures']} total failures:")
    print(f"  By region: {result['by_region']}")
    print(f"  By reason: {result['by_reason']}")

    print("\n=== All tool tests passed! ===")


def test_agent(server):
    """Test the full Strands agent (sync — called outside asyncio.run).

    Strands @tool wrappers use asyncio.run() internally, so this function
    must NOT be called from within an existing event loop.
    """
    import fakeredis.aioredis

    import common.redis_client as rc

    async def _fake_get_redis():
        return fakeredis.aioredis.FakeRedis(
            server=server, decode_responses=True,
        )
    rc.get_redis = _fake_get_redis

    from agent.system_prompt import SYSTEM_PROMPT
    from agent.tools import (
        check_spot_prices,
        get_failure_history,
        get_job_status,
        list_active_jobs,
        submit_gpu_job,
    )
    from common.config import get_settings

    settings = get_settings()
    print(f"\n=== Agent Test (model: {settings.agent_model}) ===\n")

    from strands import Agent

    agent = Agent(
        model=settings.agent_model,
        tools=[check_spot_prices, submit_gpu_job, get_job_status,
               list_active_jobs, get_failure_history],
        system_prompt=SYSTEM_PROMPT,
    )

    prompts = [
        "현재 가장 저렴한 GPU 리전이 어디인가요?",
        "g6.xlarge로 학습 작업을 제출하고 싶습니다. 가장 안정적인 리전을 추천해주세요.",
    ]

    for prompt in prompts:
        print(f">>> {prompt}")
        try:
            result = agent(prompt)
            msg = result.message
            if isinstance(msg, dict):
                text = msg.get("content", [{}])[0].get("text", str(msg))
            else:
                text = str(msg)
            print(f"<<< {text}\n")
        except Exception as e:
            print(f"<<< Error: {e}\n")
            print("(Expected if AWS credentials are not configured")
            print(" or Bedrock model access is not enabled)\n")
            break


def main():
    parser = argparse.ArgumentParser(description="Local test for GPU Spot Lotto agent")
    parser.add_argument(
        "--tools-only", action="store_true",
        help="Only test _impl functions (no AWS creds needed)",
    )
    args = parser.parse_args()

    import fakeredis
    import fakeredis.aioredis

    server = fakeredis.FakeServer()

    # Run async tool tests in a single asyncio.run call
    async def _async_tests():
        r = fakeredis.aioredis.FakeRedis(server=server, decode_responses=True)
        await seed_redis(r)
        await test_tools(r)
        await r.aclose()

    asyncio.run(_async_tests())

    # Run agent test in sync context (Strands needs its own event loops)
    if not args.tools_only:
        test_agent(server)

    print("\nDone!")


if __name__ == "__main__":
    main()
