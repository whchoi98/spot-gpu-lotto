"""Cognito JWT authentication middleware for ALB-forwarded requests."""
import base64
import json
from dataclasses import dataclass

from fastapi import Depends, HTTPException, Request

from common.config import get_settings
from common.logging import get_logger

log = get_logger("auth")


@dataclass
class CurrentUser:
    user_id: str
    role: str  # "admin" or "user"

    @property
    def is_admin(self) -> bool:
        return self.role == "admin"


def _decode_jwt_payload(token: str) -> dict:
    """Decode the payload of a JWT (no signature verification — ALB already validated)."""
    parts = token.split(".")
    if len(parts) != 3:
        raise ValueError("Invalid JWT format")
    # Base64url decode the payload (2nd part)
    payload_b64 = parts[1]
    # Add padding
    padding = 4 - len(payload_b64) % 4
    if padding != 4:
        payload_b64 += "=" * padding
    payload_bytes = base64.urlsafe_b64decode(payload_b64)
    return json.loads(payload_bytes)


async def get_current_user(request: Request) -> CurrentUser:
    """FastAPI dependency: extract current user from ALB JWT or bypass for dev."""
    settings = get_settings()

    if not settings.auth_enabled:
        return CurrentUser(user_id="dev-user", role="admin")

    token = request.headers.get("x-amzn-oidc-data")
    if not token:
        raise HTTPException(status_code=401, detail="Missing authentication token")

    try:
        payload = _decode_jwt_payload(token)
        user_id = payload.get("sub", "")
        role = payload.get("custom:role", "user")
        if not user_id:
            raise ValueError("Missing sub claim")
        return CurrentUser(user_id=user_id, role=role)
    except Exception as e:
        log.warning("auth_failed", error=str(e))
        raise HTTPException(status_code=401, detail="Invalid authentication token")


async def require_admin(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    """FastAPI dependency: require admin role."""
    if not user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return user
