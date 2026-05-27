"""Customer + debt ledger ORM models."""
from sqlalchemy import BigInteger, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.base_model import SyncMixin
from app.core.db import Base


class Customer(SyncMixin, Base):
    __tablename__ = "customers"

    name: Mapped[str] = mapped_column(String, nullable=False)
    phone: Mapped[str | None] = mapped_column(String, nullable=True)
    note: Mapped[str | None] = mapped_column(String, nullable=True)


class Debt(SyncMixin, Base):
    __tablename__ = "debts"

    customer_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    sale_id: Mapped[str | None] = mapped_column(String, nullable=True)
    currency: Mapped[str] = mapped_column(String, nullable=False)
    # Immutable original amount; balance is derived from payments — never stored.
    principal_minor: Mapped[int] = mapped_column(Integer, nullable=False)
    incurred_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    due_date: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    note: Mapped[str | None] = mapped_column(String, nullable=True)


class DebtPayment(SyncMixin, Base):
    __tablename__ = "debt_payments"

    debt_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    amount_minor: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String, nullable=False)
    paid_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
