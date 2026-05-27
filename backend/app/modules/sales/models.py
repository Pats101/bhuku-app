"""Sales ORM models."""
from sqlalchemy import BigInteger, Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.base_model import SyncMixin
from app.core.db import Base


class Sale(SyncMixin, Base):
    __tablename__ = "sales"

    customer_id: Mapped[str | None] = mapped_column(String, nullable=True)
    sold_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    currency: Mapped[str] = mapped_column(String, nullable=False)
    total_minor: Mapped[int] = mapped_column(Integer, nullable=False)
    payment_status: Mapped[str] = mapped_column(String, nullable=False)


class SaleItem(SyncMixin, Base):
    __tablename__ = "sale_items"

    sale_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    product_id: Mapped[str] = mapped_column(String, nullable=False)
    quantity: Mapped[float] = mapped_column(Float, nullable=False)
    # Price snapshotted at sale time — see ARCHITECTURE.md §5.
    unit_price_minor: Mapped[int] = mapped_column(Integer, nullable=False)
    line_total_minor: Mapped[int] = mapped_column(Integer, nullable=False)
