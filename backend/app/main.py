"""
SCAMഉണ്ടോ — FastAPI Application Entry Point

Production-ready backend for the cybersecurity mobile application.
All APIs are self-hosted. No third-party scanning services.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.exceptions import register_exception_handlers
from app.utils.logger import logger

# Import routers
from app.routers import auth, permissions, scan, issues, cyber_contacts, dashboard

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown events."""
    logger.info(f"[START] {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"[DB] {settings.DATABASE_URL.split('@')[-1] if '@' in settings.DATABASE_URL else 'configured'}")
    yield
    logger.info(f"[STOP] {settings.APP_NAME}")


# ── Create FastAPI Application ─────────────────────────────────

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "Backend API for SCAMഉണ്ടോ — a cybersecurity mobile application. "
        "Provides authentication, file scanning, threat detection history, "
        "and cyber cell contact management. All APIs are self-hosted."
    ),
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)


# ── CORS Middleware ────────────────────────────────────────────
# Allow Flutter app to communicate with the backend

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Register Exception Handlers ───────────────────────────────

register_exception_handlers(app)


# ── Register Routers ──────────────────────────────────────────

app.include_router(auth.router)
app.include_router(permissions.router)
app.include_router(scan.router)
app.include_router(issues.router)
app.include_router(cyber_contacts.router)
app.include_router(dashboard.router)


# ── Health Check ──────────────────────────────────────────────

@app.get("/", tags=["Health"], summary="API Health Check")
def health_check():
    """Root endpoint — confirms the API is running."""
    return {
        "success": True,
        "message": f"{settings.APP_NAME} is running",
        "data": {
            "version": settings.APP_VERSION,
            "status": "healthy",
        },
    }


@app.get("/health", tags=["Health"], summary="Detailed Health Check")
def detailed_health():
    """Detailed health check with service info."""
    return {
        "success": True,
        "message": "All systems operational",
        "data": {
            "app": settings.APP_NAME,
            "version": settings.APP_VERSION,
            "status": "healthy",
        },
    }
