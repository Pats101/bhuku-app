"""The set of syncable tables, in foreign-key dependency order.

Parents must come before children so that when a push applies rows, every
foreign key already resolves (e.g. a `sale` exists before its `sale_items`).
The same order is used on the client. See ARCHITECTURE.md §6.
"""
from app.core.db import Base
from app.modules.debts.models import Customer, Debt, DebtPayment
from app.modules.inventory.models import Product
from app.modules.sales.models import Sale, SaleItem

# Ordered: products & customers -> sales -> sale_items -> debts -> debt_payments
SYNC_TABLES: list[type[Base]] = [
    Product,
    Customer,
    Sale,
    SaleItem,
    Debt,
    DebtPayment,
]

# table name (matches client Drift table names) -> ORM model
MODEL_BY_TABLE: dict[str, type[Base]] = {
    model.__tablename__: model for model in SYNC_TABLES
}

# Ordered list of table names, for iterating pushes/pulls deterministically.
ORDERED_TABLE_NAMES: list[str] = [m.__tablename__ for m in SYNC_TABLES]
