"""
Custom exceptions and global exception handlers.
All error responses follow the standardized format:
{
    "success": false,
    "message": "...",
    "error_code": "...",
    "timestamp": "..."
}
"""

from datetime import datetime, timezone

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError


# ── Custom Exceptions ──────────────────────────────────────────


class DuplicateAccountError(Exception):
    """Raised when a user tries to register with an existing phone number."""

    def __init__(self, message: str = "An account with this phone number already exists"):
        self.message = message
        super().__init__(self.message)


class InvalidCredentialsError(Exception):
    """Raised when login credentials are incorrect."""

    def __init__(self, message: str = "Invalid phone number or password"):
        self.message = message
        super().__init__(self.message)


class FileValidationError(Exception):
    """Raised when an uploaded file fails validation."""

    def __init__(self, message: str = "File validation failed"):
        self.message = message
        super().__init__(self.message)





class PermissionNotFoundError(Exception):
    """Raised when permissions record does not exist for a user."""

    def __init__(self, message: str = "Permissions not found for this user"):
        self.message = message
        super().__init__(self.message)


class PermissionAlreadyExistsError(Exception):
    """Raised when permissions record already exists for a user."""

    def __init__(self, message: str = "Permissions already configured for this user"):
        self.message = message
        super().__init__(self.message)


# ── Error Response Builder ─────────────────────────────────────


def _error_json(status_code: int, message: str, error_code: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={
            "success": False,
            "message": message,
            "error_code": error_code,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
    )


# ── Exception Handlers ─────────────────────────────────────────


def register_exception_handlers(app: FastAPI) -> None:
    """Register all global exception handlers on the FastAPI app."""

    @app.exception_handler(DuplicateAccountError)
    async def duplicate_account_handler(request: Request, exc: DuplicateAccountError):
        return _error_json(409, exc.message, "DUPLICATE_ACCOUNT")

    @app.exception_handler(InvalidCredentialsError)
    async def invalid_credentials_handler(request: Request, exc: InvalidCredentialsError):
        return _error_json(401, exc.message, "INVALID_CREDENTIALS")

    @app.exception_handler(FileValidationError)
    async def file_validation_handler(request: Request, exc: FileValidationError):
        return _error_json(422, exc.message, "FILE_VALIDATION_ERROR")



    @app.exception_handler(PermissionNotFoundError)
    async def permission_not_found_handler(request: Request, exc: PermissionNotFoundError):
        return _error_json(404, exc.message, "PERMISSIONS_NOT_FOUND")

    @app.exception_handler(PermissionAlreadyExistsError)
    async def permission_exists_handler(request: Request, exc: PermissionAlreadyExistsError):
        return _error_json(409, exc.message, "PERMISSIONS_ALREADY_EXIST")

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        return _error_json(exc.status_code, str(exc.detail), "HTTP_ERROR")

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        errors = exc.errors()
        messages = "; ".join(
            f"{'.'.join(str(loc) for loc in e['loc'])}: {e['msg']}" for e in errors
        )
        return _error_json(422, f"Validation error: {messages}", "VALIDATION_ERROR")

    @app.exception_handler(Exception)
    async def general_exception_handler(request: Request, exc: Exception):
        return _error_json(500, "An unexpected error occurred", "INTERNAL_SERVER_ERROR")
