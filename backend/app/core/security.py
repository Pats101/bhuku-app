"""Supabase JWT verification.

The backend never handles passwords. Supabase Auth issues a JWT on phone+OTP
login; we verify its signature and extract the user id (`sub`), which is our
`shop_id` for the MVP (one owner == one shop).
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.core.config import Settings, get_settings

_bearer = HTTPBearer(auto_error=True)


def get_current_shop_id(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    settings: Settings = Depends(get_settings),
) -> str:
    """Verify the bearer token and return the caller's shop id (`sub`).

    Raised as 401 on any verification failure so the client knows to refresh
    its Supabase session (and meanwhile keeps working offline).
    """
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.supabase_jwt_secret,
            algorithms=[settings.supabase_jwt_algorithm],
            audience=settings.supabase_jwt_audience,
        )
    except JWTError as exc:  # noqa: BLE001 - convert to HTTP error
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc

    shop_id = payload.get("sub")
    if not shop_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing subject",
        )
    return shop_id
