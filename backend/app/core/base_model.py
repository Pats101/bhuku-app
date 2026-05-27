"""Shared sync columns for every business table.

This mirrors the Flutter `SyncColumns` mixin exactly (minus the local-only
`is_dirty` / `last_synced_at`, which never leave the device). Defining it once
guarantees both ends of the wire agree on the sync contract.

Timestamps are epoch milliseconds (UTC) stored as BIGINT — compact, sortable,
and directly comparable for last-write-wins. See ARCHITECTURE.md §5/§6.
"""
import time

from sqlalchemy import BigInteger, String
from sqlalchemy.orm import Mapped, mapped_column


def now_ms() -> int:
    """Current UTC time in epoch milliseconds (server clock, authoritative)."""
    return int(time.time() * 1000)


class SyncMixin:
    # Client-generated UUIDv4 — the primary key originates on the device.
    id: Mapped[str] = mapped_column(String, primary_key=True)
    shop_id: Mapped[str] = mapped_column(String, index=True, nullable=False)

    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    # Indexed because pull queries filter on `updated_at > since`.
    updated_at: Mapped[int] = mapped_column(
        BigInteger, nullable=False, index=True
    )
    # Soft delete: a delete is a normal row update, so it syncs and wins by LWW.
    deleted_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
