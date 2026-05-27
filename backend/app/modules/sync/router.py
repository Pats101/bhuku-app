"""Sync endpoints. Every call is authenticated and shop-scoped."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.security import get_current_shop_id
from app.modules.sync import service
from app.modules.sync.schemas import (
    PullRequest,
    PullResponse,
    PushRequest,
    PushResponse,
)

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/push", response_model=PushResponse)
async def push(
    body: PushRequest,
    shop_id: str = Depends(get_current_shop_id),
    session: AsyncSession = Depends(get_session),
) -> PushResponse:
    """Upload locally-changed rows. Returns which were applied and any rows the
    client lost under last-write-wins (so the client can adopt the server's)."""
    return await service.apply_push(session, shop_id, body.changes)


@router.post("/pull", response_model=PullResponse)
async def pull(
    body: PullRequest,
    shop_id: str = Depends(get_current_shop_id),
    session: AsyncSession = Depends(get_session),
) -> PullResponse:
    """Download everything in this shop changed since the client's cursor."""
    return await service.collect_pull(session, shop_id, body.since)
