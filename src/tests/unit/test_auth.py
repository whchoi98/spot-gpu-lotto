import base64
import json
from unittest.mock import patch

import pytest
from fastapi import HTTPException

from api_server.auth import CurrentUser, _decode_jwt_payload, get_current_user, require_admin


def _make_jwt(payload: dict) -> str:
    """Create a fake JWT with given payload (no signature verification needed)."""
    header = base64.urlsafe_b64encode(json.dumps({"alg": "ES256"}).encode()).decode().rstrip("=")
    body = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    sig = base64.urlsafe_b64encode(b"fakesig").decode().rstrip("=")
    return f"{header}.{body}.{sig}"


def test_current_user_is_admin():
    u = CurrentUser(user_id="u1", role="admin")
    assert u.is_admin is True
    u2 = CurrentUser(user_id="u2", role="user")
    assert u2.is_admin is False


def test_decode_jwt_payload():
    payload = {"sub": "user-123", "custom:role": "admin"}
    token = _make_jwt(payload)
    result = _decode_jwt_payload(token)
    assert result["sub"] == "user-123"
    assert result["custom:role"] == "admin"


def test_decode_jwt_invalid():
    with pytest.raises(ValueError, match="Invalid JWT"):
        _decode_jwt_payload("not-a-jwt")


async def test_get_current_user_auth_disabled():
    """When auth disabled, return dev user."""
    class FakeRequest:
        headers = {}

    with patch("api_server.auth.get_settings") as mock_settings:
        mock_settings.return_value.auth_enabled = False
        user = await get_current_user(FakeRequest())
        assert user.user_id == "dev-user"
        assert user.role == "admin"


async def test_get_current_user_valid_token():
    payload = {"sub": "cognito-user-456", "custom:role": "user"}
    token = _make_jwt(payload)

    class FakeRequest:
        headers = {"x-amzn-oidc-data": token}

    with patch("api_server.auth.get_settings") as mock_settings:
        mock_settings.return_value.auth_enabled = True
        user = await get_current_user(FakeRequest())
        assert user.user_id == "cognito-user-456"
        assert user.role == "user"


async def test_get_current_user_missing_token():
    class FakeRequest:
        headers = {}

    with patch("api_server.auth.get_settings") as mock_settings:
        mock_settings.return_value.auth_enabled = True
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(FakeRequest())
        assert exc_info.value.status_code == 401


async def test_get_current_user_invalid_token():
    class FakeRequest:
        headers = {"x-amzn-oidc-data": "bad.token"}

    with patch("api_server.auth.get_settings") as mock_settings:
        mock_settings.return_value.auth_enabled = True
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(FakeRequest())
        assert exc_info.value.status_code == 401


async def test_require_admin_pass():
    admin = CurrentUser(user_id="a1", role="admin")
    result = await require_admin(admin)
    assert result.user_id == "a1"


async def test_require_admin_fail():
    user = CurrentUser(user_id="u1", role="user")
    with pytest.raises(HTTPException) as exc_info:
        await require_admin(user)
    assert exc_info.value.status_code == 403
