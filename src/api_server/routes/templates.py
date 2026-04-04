"""Job template CRUD endpoints."""
from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException

from api_server.auth import CurrentUser, get_current_user
from common.models import TemplateEntry
from common.redis_client import get_redis

router = APIRouter(prefix="/api", tags=["templates"])


@router.get("/templates")
async def list_templates(user: CurrentUser = Depends(get_current_user)):
    r = await get_redis()
    templates = await r.hgetall(f"gpu:user:{user.user_id}:templates")
    return {"templates": [json.loads(v) for v in templates.values()]}


@router.post("/templates")
async def save_template(
    template: TemplateEntry,
    user: CurrentUser = Depends(get_current_user),
):
    r = await get_redis()
    key = f"gpu:user:{user.user_id}:templates"
    await r.hset(key, template.name, template.model_dump_json())
    return {"status": "saved", "name": template.name}


@router.delete("/templates/{name}")
async def delete_template(
    name: str,
    user: CurrentUser = Depends(get_current_user),
):
    r = await get_redis()
    key = f"gpu:user:{user.user_id}:templates"
    deleted = await r.hdel(key, name)
    if not deleted:
        raise HTTPException(status_code=404, detail="Template not found")
    return {"status": "deleted", "name": name}
