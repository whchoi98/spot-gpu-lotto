"""API Server - 사용자 요청을 받아 Redis 큐에 넣고 결과를 반환."""
import json
import asyncio
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import redis.asyncio as redis

app = FastAPI(title="GPU Spot Lotto")
r = redis.Redis(host="localhost", port=6379, decode_responses=True)


class JobRequest(BaseModel):
    user_id: str
    image: str = "nvidia/cuda:12.0-base"
    command: list[str] = ["/bin/sh", "-c", "nvidia-smi && sleep 60"]
    instance_type: str = "g6.xlarge"
    gpu_type: str = "l4"
    gpu_count: int = 1


@app.get("/prices")
async def get_prices():
    """현재 리전별 Spot 가격 조회."""
    prices = await r.zrange("gpu:spot:prices", 0, -1, withscores=True)
    updated = await r.get("gpu:spot:updated_at")
    return {
        "prices": [{"region_instance": m, "price": s} for m, s in prices],
        "updated_at": updated,
    }


@app.post("/jobs")
async def submit_job(req: JobRequest):
    """GPU 작업 제출 - 큐에 넣고 결과 대기."""
    job = req.model_dump()
    await r.lpush("gpu:job:queue", json.dumps(job))

    # Pub/Sub으로 결과 대기 (최대 30초)
    pubsub = r.pubsub()
    await pubsub.subscribe(f"gpu:result:{req.user_id}")
    try:
        async for msg in pubsub.listen():
            if msg["type"] == "message":
                return json.loads(msg["data"])
    except asyncio.TimeoutError:
        raise HTTPException(504, "Dispatch timeout")
    finally:
        await pubsub.unsubscribe()


@app.get("/jobs/{job_id}")
async def get_job(job_id: str):
    """작업 상태 조회."""
    info = await r.hgetall(f"gpu:jobs:{job_id}")
    if not info:
        raise HTTPException(404, "Job not found")
    return info


@app.delete("/jobs/{job_id}")
async def cancel_job(job_id: str):
    """작업 취소 및 Pod 강제 회수."""
    info = await r.hgetall(f"gpu:jobs:{job_id}")
    if not info:
        raise HTTPException(404, "Job not found")
    # dispatcher의 reaper가 처리하도록 상태만 변경
    await r.hset(f"gpu:jobs:{job_id}", "status", "cancelling")
    return {"job_id": job_id, "status": "cancelling"}
