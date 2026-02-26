from fastapi import APIRouter, Depends, HTTPException, Query, status
from datetime import date
from utils.supabase.auth import check_guard_admin_access, jwt_middleware
from utils.supabase.supabase import supabaseAdmin
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# SINGLE ANALYTICS ENDPOINT — calls one RPC, returns everything
# ─────────────────────────────────────────────────────────────────────────────
@router.get("/event/{event_id}")
async def get_event_analytics(
    event_id: int,
    query_date: str = Query(
        None,
        description="Date to analyse (YYYY-MM-DD). Defaults to today."
    ),
    user=Depends(check_guard_admin_access)
):
    """
    Complete analytics for an event in **one RPC call**.

    Sections returned:
    - `event_info`            — name, location, capacity, dates
    - `crowd_status`          — currently inside (registrations + actual people), capacity %
    - `today_summary`         — unique visitors, total entries, groups/individuals, avg duration
    - `last_hour`             — entry rate, breakdown by type (qr/bypass/manual)
    - `entry_type_breakdown`  — counts + % per entry type for the day
    - `hourly_distribution`   — entries per hour (for bar/line chart)
    - `recent_entries`        — last 10 entries with visitor details
    - `alerts`                — capacity warning, high-bypass, long-stay visitors
    - `registrations_summary` — total registered vs attended (attendance rate %)

    Pass `?query_date=YYYY-MM-DD` to view a past date.
    """
    try:
        # Use Python's local date (avoids Supabase UTC vs local timezone mismatch)
        target_date = query_date or str(date.today())

        # Validate date format
        try:
            from datetime import datetime
            datetime.strptime(target_date, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD."
            )

        # ── Single RPC call — does all 9 sections in one DB round-trip ──
        resp = supabaseAdmin.rpc(
            "get_event_analytics",
            {
                "p_event_id": event_id,
                "p_date":     target_date,
            }
        ).execute()

        if not resp.data or len(resp.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Event {event_id} not found"
            )

        row = resp.data[0]

        return {
            "success":               True,
            "event_info":            row.get("event_info",            {}),
            "crowd_status":          row.get("crowd_status",          {}),
            "today_summary":         row.get("today_summary",         {}),
            "last_hour":             row.get("last_hour",             {}),
            "entry_type_breakdown":  row.get("entry_type_breakdown",  []),
            "hourly_distribution":   row.get("hourly_distribution",   []),
            "recent_entries":        row.get("recent_entries",        []),
            "alerts":                row.get("alerts",                []),
            "registrations_summary": row.get("registrations_summary", {}),
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Analytics RPC error for event {event_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch analytics: {str(e)}"
        )

