"""S3 presigned upload URL generation."""
from __future__ import annotations
import boto3
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from common.config import get_settings
from api_server.auth import get_current_user, CurrentUser

router = APIRouter(prefix="/api", tags=["upload"])


class PresignRequest(BaseModel):
    filename: str
    prefix: str = "models"  # "models" or "datasets"


@router.post("/upload/presign")
async def presign_upload(
    req: PresignRequest,
    user: CurrentUser = Depends(get_current_user),
):
    settings = get_settings()
    if settings.k8s_mode == "dry-run":
        return {
            "url": f"https://mock-bucket.s3.amazonaws.com/{req.prefix}/{req.filename}",
            "fields": {"key": f"{req.prefix}/{req.filename}"},
        }
    s3 = boto3.client("s3")
    key = f"{req.prefix}/{user.user_id}/{req.filename}"
    presigned = s3.generate_presigned_post(
        Bucket=settings.s3_bucket if hasattr(settings, "s3_bucket") else "gpu-lotto-data",
        Key=key,
        ExpiresIn=3600,
    )
    return presigned
