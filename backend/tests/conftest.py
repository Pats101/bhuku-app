"""Test configuration.

Point the app at an in-memory async SQLite DB *before* any app module imports,
so tests need no Postgres and the module-level engine never pulls in asyncpg.
"""
import os

os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
