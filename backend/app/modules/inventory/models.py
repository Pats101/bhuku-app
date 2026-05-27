"""Inventory ORM models."""
from sqlalchemy import Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.base_model import SyncMixin
from app.core.db import Base


class Product(SyncMixin, Base):
    __tablename__ = "products"

    name: Mapped[str] = mapped_column(String, nullable=False)
    sku: Mapped[str | None] = mapped_column(String, nullable=True)
    unit: Mapped[str] = mapped_column(String, nullable=False, default="each")

    cost_price_minor: Mapped[int] = mapped_column(Integer, nullable=False)
    sell_price_minor: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String, nullable=False)

    quantity: Mapped[float] = mapped_column(Float, nullable=False, default=0)
    reorder_level: Mapped[float] = mapped_column(
        Float, nullable=False, default=0
    )
