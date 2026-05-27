"""Environment-driven application settings."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """All configuration comes from environment variables / `.env`.

    Nothing is hard-coded so the same image runs in dev, staging and prod
    (Railway/Render) with only env differences.
    """

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    # Postgres (async driver)
    database_url: str = "postgresql+asyncpg://bhuku:bhuku@localhost:5432/bhuku"

    # Supabase auth. The backend only *verifies* tokens; Supabase issues them.
    # Default Supabase access tokens are HS256 signed with the project's JWT
    # secret — set this from your Supabase dashboard (Settings -> API).
    supabase_jwt_secret: str = "change-me"
    supabase_jwt_algorithm: str = "HS256"
    # Supabase sets aud="authenticated" for signed-in users.
    supabase_jwt_audience: str = "authenticated"

    api_title: str = "Bhuku API"
    api_version: str = "0.1.0"


@lru_cache
def get_settings() -> Settings:
    return Settings()
