"""
Application configuration loaded from environment variables.
Uses Pydantic Settings for validation and type coercion.
"""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from .env file."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── Application ──────────────────────────────────────────
    APP_NAME: str = "SCAMഉണ്ടോ API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # ── Database ─────────────────────────────────────────────
    DATABASE_URL: str = "postgresql+psycopg://postgres:postgres@localhost:5432/scamundo_db"

    # ── JWT Authentication ───────────────────────────────────
    JWT_SECRET_KEY: str = "change-this-to-a-strong-random-secret-key"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRY_MINUTES: int = 1440  # 24 hours

    # ── ML Prediction Service ────────────────────────────────
    # ML integration has been removed.

    # ── File Upload ──────────────────────────────────────────
    MAX_UPLOAD_SIZE_MB: int = 10
    ALLOWED_MIME_TYPES: list[str] = [
        "application/pdf",
        "application/vnd.android.package-archive",
        "application/octet-stream",
        "text/plain",
        "text/html",
        "text/csv",
        "image/png",
        "image/jpeg",
        "image/gif",
        "image/webp",
        "application/zip",
        "application/x-zip-compressed",
        "application/json",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.ms-word.document.macroenabled.12",
        "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/vnd.ms-excel.sheet.macroenabled.12",
        "application/vnd.ms-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "application/vnd.ms-powerpoint.presentation.macroenabled.12",
        "audio/mpeg",
        "audio/mp4",
        "audio/ogg",
        "video/mp4",
        "video/webm",
    ]

    @property
    def max_upload_size_bytes(self) -> int:
        return self.MAX_UPLOAD_SIZE_MB * 1024 * 1024


@lru_cache
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()
