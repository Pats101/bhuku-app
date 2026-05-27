"""FastAPI application entrypoint."""
from fastapi import FastAPI

from app.core.config import get_settings
from app.modules.sync.router import router as sync_router

# Importing the registry pulls in every ORM model so they register on
# Base.metadata (needed by Alembic autogenerate). Feature routers are added
# here as they are built (inventory, sales, debts).
from app.modules.sync import registry  # noqa: F401

settings = get_settings()

app = FastAPI(title=settings.api_title, version=settings.api_version)

app.include_router(sync_router)


@app.get("/health", tags=["meta"])
async def health() -> dict[str, str]:
    """Liveness probe for Railway/Render and the mobile connectivity check."""
    return {"status": "ok"}
