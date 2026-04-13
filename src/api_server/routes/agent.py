"""AI Agent chat endpoint — Bedrock Converse API with Redis context."""
from __future__ import annotations

import asyncio
import json
import logging

import boto3
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from api_server.auth import CurrentUser, get_current_user
from common.config import get_settings
from common.redis_client import get_redis

router = APIRouter(prefix="/api/agent", tags=["agent"])
logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """\
You are a GPU Spot Lotto AI assistant with two capabilities:
1. GPU job scheduling advice and execution
2. System status monitoring

## GPU Instance Mapping
- L4 (24GB VRAM): g6.xlarge
- A10G (24GB): g5.xlarge
- A10G x4 (96GB): g5.12xlarge
- A10G x8 (192GB): g5.48xlarge
- L40S (48GB): g6e.xlarge
- L40S x2 (96GB): g6e.2xlarge

## Decision Guidelines
- Prefer regions with the lowest price AND available capacity > 0.
- If no region has capacity, inform the user and suggest waiting.
- Consider stability: regions with many recent failures should be avoided.

## Action Proposals (Hybrid Approval Model)
When you recommend submitting a GPU job, output a JSON code block tagged
`proposal` so the frontend can render an approval button:

```proposal
{"action":"submit_job","instance_type":"g6.xlarge",
 "image":"nvidia/cuda:12.2.0-runtime-ubuntu22.04",
 "command":"nvidia-smi","gpu_count":1,
 "region":"us-east-2","reason":"cheapest at $0.23/hr"}
```

Only propose an action when the user explicitly asks to run or submit a job.
For informational queries (prices, status), just answer with markdown.

## Formatting
- Use markdown tables for price comparisons.
- Use bold for key numbers and region names.
- Respond in the same language the user uses (Korean or English).
- Show prices in USD per hour.
"""


class ChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatMessage] = []


class ProposedAction(BaseModel):
    action: str
    instance_type: str | None = None
    image: str | None = None
    command: str | None = None
    gpu_count: int | None = None
    region: str | None = None
    reason: str | None = None


class ChatResponse(BaseModel):
    content: str
    model: str
    actions: list[ProposedAction] = []


def _build_context(prices: list[dict], stats: dict, regions: list[dict]) -> str:
    """Build real-time context string from Redis data."""
    lines = ["## Current System State\n"]

    if prices:
        lines.append("### Spot Prices (sorted cheapest-first)")
        lines.append("| Region | Instance | Price/hr |")
        lines.append("|--------|----------|----------|")
        for p in sorted(prices, key=lambda x: x["price"]):
            lines.append(f"| {p['region']} | {p['instance_type']} | ${p['price']:.4f} |")
    else:
        lines.append("### Spot Prices\nNo price data available.")

    lines.append("\n### System Stats")
    lines.append(f"- Active jobs: {stats.get('active_jobs', 0)}")
    lines.append(f"- Queue depth: {stats.get('queue_depth', 0)}")

    if regions:
        lines.append("\n### Region Capacity")
        for r in regions:
            lines.append(f"- **{r['region']}**: {r['available_capacity']} slots available")

    return "\n".join(lines)


async def _fetch_context() -> str:
    """Fetch prices, stats, and capacity from Redis."""
    r = await get_redis()
    settings = get_settings()

    # Prices
    all_prices = await r.zrange("gpu:spot:prices", 0, -1, withscores=True)
    prices = []
    for member, score in all_prices:
        region, itype = member.rsplit(":", 1)
        prices.append({"region": region, "instance_type": itype, "price": score})

    # Stats
    active_count = await r.scard("gpu:active_jobs")
    queue_len = await r.llen("gpu:job:queue")
    stats = {"active_jobs": active_count, "queue_depth": queue_len}

    # Region capacity
    regions = []
    for region in settings.regions:
        cap = await r.get(f"gpu:capacity:{region}")
        regions.append({"region": region, "available_capacity": int(cap) if cap else 0})

    return _build_context(prices, stats, regions)


def _call_bedrock(system: str, messages: list[dict], model_id: str) -> str:
    """Call Bedrock Converse API (sync — run in thread pool)."""
    client = boto3.client("bedrock-runtime", region_name="us-east-1")

    converse_messages = []
    for msg in messages:
        converse_messages.append({
            "role": msg["role"],
            "content": [{"text": msg["content"]}],
        })

    response = client.converse(
        modelId=model_id,
        system=[{"text": system}],
        messages=converse_messages,
        inferenceConfig={"maxTokens": 4096, "temperature": 0.3},
    )

    output = response["output"]["message"]["content"]
    return output[0]["text"] if output else ""


def _extract_actions(text: str) -> list[ProposedAction]:
    """Extract proposed actions from ```proposal code blocks."""
    actions = []
    parts = text.split("```proposal")
    for part in parts[1:]:
        end = part.find("```")
        if end == -1:
            continue
        json_str = part[:end].strip()
        try:
            data = json.loads(json_str)
            actions.append(ProposedAction(**data))
        except (json.JSONDecodeError, TypeError):
            continue
    return actions


@router.post("/chat", response_model=ChatResponse)
async def agent_chat(
    body: ChatRequest,
    user: CurrentUser = Depends(get_current_user),
):
    """Chat with the AI agent. Returns markdown response with optional action proposals."""
    settings = get_settings()

    # Fetch real-time context from Redis
    context = await _fetch_context()

    # Build system prompt with context
    full_system = f"{SYSTEM_PROMPT}\n\n{context}"

    # Build conversation history
    messages = [{"role": m.role, "content": m.content} for m in body.history]
    messages.append({"role": "user", "content": body.message})

    # Call Bedrock Claude (sync call in thread pool)
    model_id = settings.agent_model
    try:
        response_text = await asyncio.to_thread(
            _call_bedrock, full_system, messages, model_id,
        )
    except Exception as e:
        logger.exception("Bedrock Converse API call failed")
        raise HTTPException(status_code=502, detail=f"Agent error: {e}")

    # Extract proposed actions from response
    actions = _extract_actions(response_text)

    # Clean proposal blocks from the displayed content
    clean_content = response_text
    for block_start in ["```proposal"]:
        while block_start in clean_content:
            start = clean_content.find(block_start)
            end = clean_content.find("```", start + len(block_start))
            if end != -1:
                clean_content = clean_content[:start] + clean_content[end + 3:]
            else:
                break

    return ChatResponse(
        content=clean_content.strip(),
        model=model_id,
        actions=actions,
    )
