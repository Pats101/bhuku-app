"""Tests for the sync engine's last-write-wins and tenant-scoping rules.

Runs against an in-memory async SQLite database so it's fast and needs no
Postgres. The schema is created from the same ORM metadata used in production.
"""
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.db import Base
from app.modules.inventory.models import Product
from app.modules.sync import service

# Importing the registry registers all models on Base.metadata.
from app.modules.sync import registry  # noqa: F401

SHOP = "shop-1"
OTHER_SHOP = "shop-2"


def _product_row(id_: str, name: str, updated_at: int, qty: float = 10) -> dict:
    return {
        "id": id_,
        "shop_id": SHOP,
        "created_at": 1000,
        "updated_at": updated_at,
        "deleted_at": None,
        "name": name,
        "sku": None,
        "unit": "each",
        "cost_price_minor": 100,
        "sell_price_minor": 150,
        "currency": "USD",
        "quantity": qty,
        "reorder_level": 2,
        # client-only column that must be ignored by the server:
        "is_dirty": True,
    }


@pytest_asyncio.fixture
async def session() -> AsyncSession:
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as s:
        yield s
    await engine.dispose()


@pytest.mark.asyncio
async def test_push_inserts_new_row_and_ignores_client_only_columns(session):
    res = await service.apply_push(
        session, SHOP, {"products": [_product_row("p1", "Sugar", 2000)]}
    )
    assert res.applied == ["p1"]
    saved = await session.get(Product, "p1")
    assert saved is not None and saved.name == "Sugar"
    assert not hasattr(saved, "is_dirty")  # client-only column was dropped


@pytest.mark.asyncio
async def test_newer_incoming_update_wins(session):
    await service.apply_push(
        session, SHOP, {"products": [_product_row("p1", "Old", 2000)]}
    )
    res = await service.apply_push(
        session, SHOP, {"products": [_product_row("p1", "New", 3000)]}
    )
    assert res.applied == ["p1"]
    assert res.conflicts == []
    assert (await session.get(Product, "p1")).name == "New"


@pytest.mark.asyncio
async def test_older_incoming_update_loses_and_returns_conflict(session):
    await service.apply_push(
        session, SHOP, {"products": [_product_row("p1", "Server", 3000)]}
    )
    res = await service.apply_push(
        session, SHOP, {"products": [_product_row("p1", "Stale", 2000)]}
    )
    assert res.applied == []
    assert len(res.conflicts) == 1
    assert res.conflicts[0]["name"] == "Server"  # server copy preserved
    assert (await session.get(Product, "p1")).name == "Server"


@pytest.mark.asyncio
async def test_pull_returns_only_rows_after_cursor(session):
    await service.apply_push(
        session, SHOP, {"products": [_product_row("p1", "A", 1000)]}
    )
    await service.apply_push(
        session, SHOP, {"products": [_product_row("p2", "B", 5000)]}
    )
    res = await service.collect_pull(session, SHOP, since=2000)
    ids = [r["id"] for r in res.changes["products"]]
    assert ids == ["p2"]  # p1 (updated_at 1000) is before the cursor
    assert res.server_time >= 5000


@pytest.mark.asyncio
async def test_pull_is_scoped_to_shop(session):
    row = _product_row("p1", "Mine", 1000)
    await service.apply_push(session, SHOP, {"products": [row]})
    res = await service.collect_pull(session, OTHER_SHOP, since=0)
    assert res.changes["products"] == []  # other shop sees nothing
