"""
Dashboard service — aggregates scan history into time-bucketed statistics.

Queries the scan_history table directly using the same SQLAlchemy patterns
used across the rest of the codebase (e.g. auth_service, scan_service).
"""

import uuid
from datetime import datetime, timezone, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.scan_history import ScanHistory
from app.schemas.dashboard import (
    DashboardStatsResponse,
    PeriodStats,
    ThreatBreakdown,
    RiskBreakdown,
)


def _period_start(period: str) -> datetime:
    """Return the UTC start-of-period timestamp."""
    now = datetime.now(timezone.utc)

    if period == "today":
        return now.replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == "this_week":
        # Monday = start of ISO week
        start = now - timedelta(days=now.weekday())
        return start.replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == "this_month":
        return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    else:
        # all_time — earliest possible date
        return datetime.min.replace(tzinfo=timezone.utc)


def _build_period_stats(db: Session, user_id: uuid.UUID, since: datetime) -> PeriodStats:
    """
    Run a grouped query on scan_history for a single time period.

    Returns counts by verdict and risk_level, plus a total threats_blocked
    figure (malicious + suspicious).
    """
    rows = (
        db.query(
            ScanHistory.verdict,
            ScanHistory.risk_level,
            func.count().label("cnt"),
        )
        .filter(ScanHistory.user_id == user_id)
        .filter(ScanHistory.scanned_at >= since)
        .group_by(ScanHistory.verdict, ScanHistory.risk_level)
        .all()
    )

    threats = ThreatBreakdown()
    risk = RiskBreakdown()
    total = 0

    for verdict, risk_level, count in rows:
        total += count

        # Verdict counts
        v = verdict.lower()
        if v == "malicious":
            threats.malicious += count
        elif v == "suspicious":
            threats.suspicious += count
        elif v == "safe":
            threats.safe += count

        # Risk level counts
        r = risk_level.lower()
        if r == "critical":
            risk.critical += count
        elif r == "high":
            risk.high += count
        elif r == "medium":
            risk.medium += count
        elif r == "low":
            risk.low += count

    return PeriodStats(
        total_scans=total,
        threats_blocked=threats.malicious + threats.suspicious,
        threats=threats,
        risk=risk,
    )


def get_dashboard_stats(db: Session, user_id: uuid.UUID) -> DashboardStatsResponse:
    """
    Build the full dashboard response for the authenticated user.

    Returns stats bucketed into four time periods:
      today, this_week, this_month, all_time
    """
    return DashboardStatsResponse(
        today=_build_period_stats(db, user_id, _period_start("today")),
        this_week=_build_period_stats(db, user_id, _period_start("this_week")),
        this_month=_build_period_stats(db, user_id, _period_start("this_month")),
        all_time=_build_period_stats(db, user_id, _period_start("all_time")),
    )
