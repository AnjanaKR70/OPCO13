"""
Pydantic schemas for dashboard statistics.
"""

from pydantic import BaseModel


class ThreatBreakdown(BaseModel):
    """Count of scans grouped by verdict."""

    malicious: int = 0
    suspicious: int = 0
    safe: int = 0


class RiskBreakdown(BaseModel):
    """Count of scans grouped by risk level."""

    critical: int = 0
    high: int = 0
    medium: int = 0
    low: int = 0


class PeriodStats(BaseModel):
    """Statistics for a single time period (today / this week / this month)."""

    total_scans: int = 0
    threats_blocked: int = 0  # malicious + suspicious
    threats: ThreatBreakdown = ThreatBreakdown()
    risk: RiskBreakdown = RiskBreakdown()


class DashboardStatsResponse(BaseModel):
    """Full dashboard payload returned to the frontend."""

    today: PeriodStats = PeriodStats()
    this_week: PeriodStats = PeriodStats()
    this_month: PeriodStats = PeriodStats()
    all_time: PeriodStats = PeriodStats()
