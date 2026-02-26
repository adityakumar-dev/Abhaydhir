"""
India timezone helpers — use these everywhere instead of date.today() / datetime.utcnow().

IST = UTC + 05:30
"""
from datetime import datetime, date
from zoneinfo import ZoneInfo

IST = ZoneInfo("Asia/Kolkata")


def india_now() -> datetime:
    """Return current datetime in IST (timezone-aware)."""
    return datetime.now(IST)


def india_today() -> date:
    """Return today's date in IST."""
    return datetime.now(IST).date()


def india_today_str() -> str:
    """Return today's date in IST as 'YYYY-MM-DD' string."""
    return datetime.now(IST).strftime("%Y-%m-%d")
