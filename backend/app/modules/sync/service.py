"""Sync engine: push (last-write-wins upsert) and pull (delta since cursor).

All operations are scoped to the caller's `shop_id`, taken from the verified
JWT — a client can never read or write another shop's data, regardless of what
it sends in the payload.

Idempotent by construction: re-pushing an already-applied row (same id, equal
or older `updated_at`) is a no-op, so a connection dropped mid-sync is always
safe to retry. See ARCHITECTURE.md §6.
"""
from sqlalchemy import inspect, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.base_model import now_ms
from app.core.db import Base
from app.modules.sync.registry import MODEL_BY_TABLE, ORDERED_TABLE_NAMES
from app.modules.sync.schemas import (
    ChangeSet,
    PullResponse,
    PushResponse,
)


def _columns(model: type[Base]) -> set[str]:
    return {c.key for c in inspect(model).columns}


def _to_dict(instance: Base) -> dict:
    return {c.key: getattr(instance, c.key) for c in inspect(instance).mapper.columns}


async def apply_push(
    session: AsyncSession, shop_id: str, changes: ChangeSet
) -> PushResponse:
    applied: list[str] = []
    conflicts: list[dict] = []

    # Parents before children so foreign keys always resolve on insert.
    for table in ORDERED_TABLE_NAMES:
        rows = changes.get(table, [])
        if not rows:
            continue
        model = MODEL_BY_TABLE[table]
        allowed = _columns(model)

        for raw in rows:
            # Drop unknown keys (e.g. client-only is_dirty) and force tenant.
            row = {k: v for k, v in raw.items() if k in allowed}
            row["shop_id"] = shop_id
            row_id = row.get("id")
            incoming_updated = row.get("updated_at", 0)
            if row_id is None:
                continue  # malformed; skip rather than 500 the whole batch

            existing = await session.get(model, row_id)
            if existing is None:
                session.add(model(**row))
                applied.append(row_id)
            elif existing.shop_id != shop_id:
                # Not this caller's row — never touch it.
                continue
            elif existing.updated_at >= incoming_updated:
                # Server's copy is newer (or tied) -> server wins.
                conflicts.append(_to_dict(existing))
            else:
                for key, value in row.items():
                    setattr(existing, key, value)
                applied.append(row_id)

        await session.flush()

    return PushResponse(applied=applied, conflicts=conflicts)


async def collect_pull(
    session: AsyncSession, shop_id: str, since: int
) -> PullResponse:
    # Snapshot the cursor BEFORE reading so rows written during this request are
    # caught by the next pull (since uses a strict `>`), never skipped.
    server_time = now_ms()
    changes: ChangeSet = {}

    for table in ORDERED_TABLE_NAMES:
        model = MODEL_BY_TABLE[table]
        stmt = select(model).where(
            model.shop_id == shop_id,
            model.updated_at > since,  # includes soft-deleted rows -> propagate
        )
        result = await session.execute(stmt)
        changes[table] = [_to_dict(r) for r in result.scalars().all()]

    return PullResponse(changes=changes, server_time=server_time)
