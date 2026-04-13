"""S3 presigned upload URL generation."""
from __future__ import annotations

import os

import boto3
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from api_server.auth import CurrentUser, get_current_user
from common.config import get_settings

router = APIRouter(prefix="/api", tags=["upload"])

_ALLOWED_PREFIXES = {"models", "datasets"}


class PresignRequest(BaseModel):
    filename: str
    prefix: str = "models"  # "models" or "datasets"


def _sanitize_filename(filename: str) -> str:
    """Strip path components to prevent directory traversal."""
    safe = os.path.basename(filename)
    if not safe or safe.startswith("."):
        raise HTTPException(status_code=400, detail="Invalid filename")
    return safe


@router.post("/upload/presign")
async def presign_upload(
    req: PresignRequest,
    user: CurrentUser = Depends(get_current_user),
):
    if req.prefix not in _ALLOWED_PREFIXES:
        raise HTTPException(status_code=400, detail=f"prefix must be one of {_ALLOWED_PREFIXES}")
    safe_filename = _sanitize_filename(req.filename)
    settings = get_settings()
    if settings.k8s_mode == "dry-run":
        return {
            "url": f"https://mock-bucket.s3.amazonaws.com/{req.prefix}/{safe_filename}",
            "fields": {"key": f"{req.prefix}/{safe_filename}"},
        }
    s3 = boto3.client("s3")
    key = f"{req.prefix}/{user.user_id}/{safe_filename}"
    presigned = s3.generate_presigned_post(
        Bucket=settings.s3_bucket if hasattr(settings, "s3_bucket") else "gpu-lotto-data",
        Key=key,
        ExpiresIn=3600,
    )
    return presigned
