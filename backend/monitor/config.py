"""
Registry of supported applications for SCAMഉണ്ടോ Pre-Interaction Monitoring.
Frontend toggles can modify these configurations.
"""

MONITORED_APPS = {
    "WhatsApp": True,
    "Telegram": True,
    "Instagram": False,
    "Facebook": False,
    "Gmail": True,
    "Chrome": True,
    "Downloads Folder": True,
    "System": True
}

def is_monitoring_enabled(app_name: str) -> bool:
    """Returns True if the application is recognized and currently toggled ON."""
    return MONITORED_APPS.get(app_name, False)
