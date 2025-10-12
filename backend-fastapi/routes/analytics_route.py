from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Optional
from datetime import datetime, timedelta
from utils.supabase.auth import jwt_middleware, check_guard_admin_access
from utils.supabase.supabase import supabaseAdmin
from utils.supabase.query_helper import execute_raw_sql, execute_raw_sql_single
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

# ------------------------------------------------------------
# COMPREHENSIVE EVENT ANALYTICS FOR SECURITY
# ------------------------------------------------------------
@router.get("/event/{event_id}/security-analytics")
async def get_event_security_analytics(
    event_id: int,
    user_data: dict = Depends(jwt_middleware)
):
    """
    Comprehensive analytics for security dashboard showing:
    - Real-time crowd status (currently inside)
    - Last hour entry statistics
    - Today's entry summary
    - Average scanning/processing time
    - Entry type breakdown (normal/bypass/manual)
    - Peak hours analysis
    - Group vs Individual statistics
    """
    try:
        # Verify event exists
        event_response = supabaseAdmin.table("events").select("*").eq("event_id", event_id).single().execute()
        if not event_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Event with ID {event_id} not found"
            )
        
        event_data = event_response.data
        now = datetime.now()
        today = now.date()
        one_hour_ago = now - timedelta(hours=1)
        
        # ============================================================
        # 1. CURRENT CROWD STATUS (Currently Inside)
        # ============================================================
        crowd_query = f"""
            SELECT 
                COUNT(DISTINCT er.user_id) as total_inside,
                SUM(CASE WHEN t.is_group THEN t.group_count ELSE 1 END) as total_people_inside,
                COUNT(DISTINCT CASE WHEN t.is_group THEN er.user_id END) as groups_inside,
                COUNT(DISTINCT CASE WHEN NOT t.is_group THEN er.user_id END) as individuals_inside
            FROM entry_records er
            JOIN tourists t ON t.user_id = er.user_id
            WHERE er.event_id = {event_id}
            AND er.entry_date = '{today}'
            AND EXISTS (
                SELECT 1 FROM entry_items ei
                WHERE ei.record_id = er.record_id
                AND ei.departure_time IS NULL
            )
        """
        crowd_results = await execute_raw_sql(crowd_query)
        crowd_data = crowd_results[0] if crowd_results else {
            "total_inside": 0, 
            "total_people_inside": 0,
            "groups_inside": 0,
            "individuals_inside": 0
        }
        
        # Ensure all values are integers, not None
        crowd_data = {
            "total_inside": crowd_data.get("total_inside") or 0,
            "total_people_inside": crowd_data.get("total_people_inside") or 0,
            "groups_inside": crowd_data.get("groups_inside") or 0,
            "individuals_inside": crowd_data.get("individuals_inside") or 0
        }
        
        # ============================================================
        # 2. LAST HOUR ENTRY STATISTICS
        # ============================================================
        last_hour_query = f"""
            SELECT 
                COUNT(DISTINCT ei.item_id) as entries_last_hour,
                COUNT(DISTINCT er.user_id) as unique_visitors_last_hour,
                COUNT(DISTINCT CASE WHEN ei.entry_type = 'normal' THEN ei.item_id END) as normal_entries,
                COUNT(DISTINCT CASE WHEN ei.entry_type = 'bypass' THEN ei.item_id END) as bypass_entries,
                COUNT(DISTINCT CASE WHEN ei.entry_type = 'manual' THEN ei.item_id END) as manual_entries,
                AVG(EXTRACT(EPOCH FROM (ei.metadata->>'processing_time')::INTERVAL)) as avg_processing_seconds
            FROM entry_items ei
            JOIN entry_records er ON er.record_id = ei.record_id
            WHERE er.event_id = {event_id}
            AND ei.arrival_time >= '{one_hour_ago.isoformat()}'
            AND ei.arrival_time <= '{now.isoformat()}'
        """
        last_hour_results = await execute_raw_sql(last_hour_query)
        last_hour_data = last_hour_results[0] if last_hour_results else {
            "entries_last_hour": 0,
            "unique_visitors_last_hour": 0,
            "normal_entries": 0,
            "bypass_entries": 0,
            "manual_entries": 0,
            "avg_processing_seconds": 0
        }
        
        # Ensure all values are not None
        last_hour_data = {
            "entries_last_hour": last_hour_data.get("entries_last_hour") or 0,
            "unique_visitors_last_hour": last_hour_data.get("unique_visitors_last_hour") or 0,
            "normal_entries": last_hour_data.get("normal_entries") or 0,
            "bypass_entries": last_hour_data.get("bypass_entries") or 0,
            "manual_entries": last_hour_data.get("manual_entries") or 0,
            "avg_processing_seconds": last_hour_data.get("avg_processing_seconds") or 0
        }
        
        # ============================================================
        # 3. TODAY'S COMPLETE SUMMARY
        # ============================================================
        today_summary_query = f"""
            SELECT 
                COUNT(DISTINCT er.user_id) as total_unique_visitors,
                COUNT(DISTINCT ei.item_id) as total_entries,
                SUM(CASE WHEN t.is_group THEN t.group_count ELSE 1 END) as total_people_count,
                COUNT(DISTINCT CASE WHEN t.is_group THEN er.user_id END) as total_groups,
                COUNT(DISTINCT CASE WHEN NOT t.is_group THEN er.user_id END) as total_individuals,
                COUNT(DISTINCT CASE WHEN ei.departure_time IS NOT NULL THEN er.user_id END) as exited_visitors,
                AVG(EXTRACT(EPOCH FROM ei.duration)) as avg_visit_duration_seconds
            FROM entry_records er
            JOIN tourists t ON t.user_id = er.user_id
            LEFT JOIN entry_items ei ON ei.record_id = er.record_id
            WHERE er.event_id = {event_id}
            AND er.entry_date = '{today}'
        """
        today_results = await execute_raw_sql(today_summary_query)
        today_data = today_results[0] if today_results else {}
        
        # Ensure all values are not None
        today_data = {
            "total_unique_visitors": today_data.get("total_unique_visitors") or 0,
            "total_entries": today_data.get("total_entries") or 0,
            "total_people_count": today_data.get("total_people_count") or 0,
            "total_groups": today_data.get("total_groups") or 0,
            "total_individuals": today_data.get("total_individuals") or 0,
            "exited_visitors": today_data.get("exited_visitors") or 0,
            "avg_visit_duration_seconds": today_data.get("avg_visit_duration_seconds") or 0
        }
        
        # ============================================================
        # 4. ENTRY TYPE BREAKDOWN (Today)
        # ============================================================
        entry_type_query = f"""
            SELECT 
                ei.entry_type,
                COUNT(*) as count,
                ROUND(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) as percentage
            FROM entry_items ei
            JOIN entry_records er ON er.record_id = ei.record_id
            WHERE er.event_id = {event_id}
            AND er.entry_date = '{today}'
            GROUP BY ei.entry_type
            ORDER BY count DESC
        """
        entry_types = await execute_raw_sql(entry_type_query)
        
        # ============================================================
        # 5. HOURLY DISTRIBUTION (Today)
        # ============================================================
        hourly_query = f"""
            SELECT 
                EXTRACT(HOUR FROM ei.arrival_time) as hour,
                COUNT(DISTINCT ei.item_id) as entries,
                COUNT(DISTINCT er.user_id) as unique_visitors
            FROM entry_items ei
            JOIN entry_records er ON er.record_id = ei.record_id
            WHERE er.event_id = {event_id}
            AND DATE(ei.arrival_time) = '{today}'
            GROUP BY hour
            ORDER BY hour
        """
        hourly_data = await execute_raw_sql(hourly_query)
        
        # Find peak hour
        peak_hour = max(hourly_data, key=lambda x: x['entries']) if hourly_data else None
        
        # ============================================================
        # 6. AVERAGE SCANNING/PROCESSING TIME
        # ============================================================
        scanning_query = f"""
            SELECT 
                AVG(EXTRACT(EPOCH FROM (ei.metadata->>'scan_time')::INTERVAL)) as avg_scan_seconds,
                MIN(EXTRACT(EPOCH FROM (ei.metadata->>'scan_time')::INTERVAL)) as min_scan_seconds,
                MAX(EXTRACT(EPOCH FROM (ei.metadata->>'scan_time')::INTERVAL)) as max_scan_seconds,
                PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (ei.metadata->>'scan_time')::INTERVAL)) as median_scan_seconds
            FROM entry_items ei
            JOIN entry_records er ON er.record_id = ei.record_id
            WHERE er.event_id = {event_id}
            AND er.entry_date = '{today}'
            AND ei.metadata->>'scan_time' IS NOT NULL
        """
        scanning_results = await execute_raw_sql(scanning_query)
        scanning_data = scanning_results[0] if scanning_results else {
            "avg_scan_seconds": 0,
            "min_scan_seconds": 0,
            "max_scan_seconds": 0,
            "median_scan_seconds": 0
        }
        
        # Ensure all values are not None
        scanning_data = {
            "avg_scan_seconds": scanning_data.get("avg_scan_seconds") or 0,
            "min_scan_seconds": scanning_data.get("min_scan_seconds") or 0,
            "max_scan_seconds": scanning_data.get("max_scan_seconds") or 0,
            "median_scan_seconds": scanning_data.get("median_scan_seconds") or 0
        }
        
        # ============================================================
        # 7. RECENT ENTRIES (Last 10)
        # ============================================================
        recent_entries_query = f"""
            SELECT 
                t.name,
                t.unique_id_type,
                t.is_group,
                t.group_count,
                ei.arrival_time,
                ei.entry_type,
                ei.departure_time
            FROM entry_items ei
            JOIN entry_records er ON er.record_id = ei.record_id
            JOIN tourists t ON t.user_id = er.user_id
            WHERE er.event_id = {event_id}
            AND er.entry_date = '{today}'
            ORDER BY ei.arrival_time DESC
            LIMIT 10
        """
        recent_entries = await execute_raw_sql(recent_entries_query)
        
        # ============================================================
        # 8. CAPACITY ANALYSIS
        # ============================================================
        capacity_percentage = 0
        capacity_status = "unknown"
        if event_data.get('max_capacity'):
            total_people_inside = crowd_data.get('total_people_inside') or 0
            max_capacity = event_data.get('max_capacity') or 1  # Avoid division by zero
            
            capacity_percentage = round(
                (total_people_inside / max_capacity) * 100, 
                2
            )
            if capacity_percentage >= 90:
                capacity_status = "critical"
            elif capacity_percentage >= 75:
                capacity_status = "high"
            elif capacity_percentage >= 50:
                capacity_status = "moderate"
            else:
                capacity_status = "low"
        
        # ============================================================
        # COMPILE COMPLETE ANALYTICS RESPONSE
        # ============================================================
        analytics = {
            "event": {
                "event_id": event_data['event_id'],
                "name": event_data['name'],
                "location": event_data['location'],
                "max_capacity": event_data.get('max_capacity'),
                "date": str(today),
                "current_time": now.isoformat()
            },
            "crowd_status": {
                "currently_inside": crowd_data['total_inside'],
                "total_people_inside": crowd_data['total_people_inside'],
                "groups_inside": crowd_data['groups_inside'],
                "individuals_inside": crowd_data['individuals_inside'],
                "capacity_percentage": capacity_percentage,
                "capacity_status": capacity_status
            },
            "last_hour": {
                "entries": last_hour_data.get('entries_last_hour', 0),
                "unique_visitors": last_hour_data.get('unique_visitors_last_hour', 0),
                "entry_rate_per_minute": round((last_hour_data.get('entries_last_hour') or 0) / 60, 2),
                "normal_entries": last_hour_data.get('normal_entries', 0),
                "bypass_entries": last_hour_data.get('bypass_entries', 0),
                "manual_entries": last_hour_data.get('manual_entries', 0),
                "avg_processing_time_seconds": round(last_hour_data.get('avg_processing_seconds', 0) or 0, 2)
            },
            "today_summary": {
                "total_unique_visitors": today_data.get('total_unique_visitors', 0),
                "total_entries": today_data.get('total_entries', 0),
                "total_people_count": today_data.get('total_people_count', 0),
                "total_groups": today_data.get('total_groups', 0),
                "total_individuals": today_data.get('total_individuals', 0),
                "exited_visitors": today_data.get('exited_visitors', 0),
                "avg_visit_duration_minutes": round((today_data.get('avg_visit_duration_seconds') or 0) / 60, 2)
            },
            "entry_types": entry_types,
            "hourly_distribution": hourly_data,
            "peak_hour": {
                "hour": int(peak_hour['hour']) if peak_hour else None,
                "entries": peak_hour['entries'] if peak_hour else 0,
                "unique_visitors": peak_hour['unique_visitors'] if peak_hour else 0
            } if peak_hour else None,
            "scanning_performance": {
                "avg_scan_time_seconds": round(scanning_data.get('avg_scan_seconds', 0) or 0, 2),
                "min_scan_time_seconds": round(scanning_data.get('min_scan_seconds', 0) or 0, 2),
                "max_scan_time_seconds": round(scanning_data.get('max_scan_seconds', 0) or 0, 2),
                "median_scan_time_seconds": round(scanning_data.get('median_scan_seconds', 0) or 0, 2)
            },
            "recent_entries": recent_entries
        }
        
        return {
            "success": True,
            "analytics": analytics,
            "generated_at": now.isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching event analytics: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch event analytics: {str(e)}"
        )


# ------------------------------------------------------------
# LIVE ENTRY FEED FOR SECURITY MONITORING
# ------------------------------------------------------------
@router.get("/event/{event_id}/live-feed")
async def get_live_entry_feed(
    event_id: int,
    limit: int = Query(20, description="Number of recent entries to fetch"),
    user_data: dict = Depends(jwt_middleware)
):
    """
    Live feed of entries for real-time security monitoring
    Shows recent entries with visitor details and status
    """
    try:
        live_feed_query = f"""
            SELECT 
                ei.item_id,
                t.user_id,
                t.name,
                t.unique_id_type,
                t.unique_id,
                t.is_group,
                t.group_count,
                ei.arrival_time,
                ei.departure_time,
                ei.entry_type,
                ei.bypass_reason,
                CASE 
                    WHEN ei.departure_time IS NULL THEN 'inside'
                    ELSE 'exited'
                END as current_status,
                EXTRACT(EPOCH FROM (NOW() - ei.arrival_time)) as time_inside_seconds
            FROM entry_items ei
            JOIN entry_records er ON er.record_id = ei.record_id
            JOIN tourists t ON t.user_id = er.user_id
            WHERE er.event_id = {event_id}
            AND er.entry_date = CURRENT_DATE
            ORDER BY ei.arrival_time DESC
            LIMIT {limit}
        """
        
        entries = await execute_raw_sql(live_feed_query)
        
        return {
            "success": True,
            "entries": entries,
            "count": len(entries),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error fetching live feed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch live feed: {str(e)}"
        )


# ------------------------------------------------------------
# ALERTS & NOTIFICATIONS FOR SECURITY
# ------------------------------------------------------------
@router.get("/event/{event_id}/security-alerts")
async def get_security_alerts(
    event_id: int,
    user_data: dict = Depends(jwt_middleware)
):
    """
    Get security alerts and notifications:
    - High capacity warnings
    - Unusual bypass activity
    - Long processing times
    - Suspicious patterns
    """
    try:
        alerts = []
        now = datetime.now()
        today = now.date()
        
        # Check event capacity
        event_response = supabaseAdmin.table("events").select("*").eq("event_id", event_id).single().execute()
        event_data = event_response.data
        
        # Get current crowd
        crowd_query = f"""
            SELECT 
                COUNT(DISTINCT er.user_id) as total_inside,
                SUM(CASE WHEN t.is_group THEN t.group_count ELSE 1 END) as total_people_inside
            FROM entry_records er
            JOIN tourists t ON t.user_id = er.user_id
            WHERE er.event_id = {event_id}
            AND er.entry_date = '{today}'
            AND EXISTS (
                SELECT 1 FROM entry_items ei
                WHERE ei.record_id = er.record_id
                AND ei.departure_time IS NULL
            )
        """
        crowd_results = await execute_raw_sql(crowd_query)
        crowd_data = crowd_results[0] if crowd_results else {"total_people_inside": 0}
        
        # Ensure values are not None
        total_people_inside = crowd_data.get('total_people_inside') or 0
        
        # Alert 1: Capacity Warning
        if event_data.get('max_capacity'):
            max_capacity = event_data.get('max_capacity') or 1  # Avoid division by zero
            capacity_percentage = (total_people_inside / max_capacity) * 100
            if capacity_percentage >= 90:
                alerts.append({
                    "type": "capacity_critical",
                    "severity": "critical",
                    "message": f"Capacity at {round(capacity_percentage, 1)}% - Critical level",
                    "data": {
                        "current": total_people_inside,
                        "max": event_data['max_capacity'],
                        "percentage": round(capacity_percentage, 2)
                    }
                })
            elif capacity_percentage >= 75:
                alerts.append({
                    "type": "capacity_high",
                    "severity": "warning",
                    "message": f"Capacity at {round(capacity_percentage, 1)}% - High level",
                    "data": {
                        "current": total_people_inside,
                        "max": event_data['max_capacity'],
                        "percentage": round(capacity_percentage, 2)
                    }
                })
        
        # Alert 2: Unusual Bypass Activity
        bypass_query = f"""
            SELECT COUNT(*) as bypass_count
            FROM entry_items ei
            JOIN entry_records er ON er.record_id = ei.record_id
            WHERE er.event_id = {event_id}
            AND er.entry_date = '{today}'
            AND ei.entry_type = 'bypass'
            AND ei.arrival_time >= NOW() - INTERVAL '1 hour'
        """
        bypass_results = await execute_raw_sql(bypass_query)
        bypass_count = (bypass_results[0].get('bypass_count') or 0) if bypass_results else 0
        
        if bypass_count > 10:  # More than 10 bypasses in last hour
            alerts.append({
                "type": "high_bypass_activity",
                "severity": "warning",
                "message": f"High bypass activity detected: {bypass_count} bypasses in last hour",
                "data": {"bypass_count": bypass_count}
            })
        
        # Alert 3: People inside for too long (> 4 hours)
        long_stay_query = f"""
            SELECT 
                t.name,
                t.user_id,
                ei.arrival_time,
                EXTRACT(EPOCH FROM (NOW() - ei.arrival_time)) / 3600 as hours_inside
            FROM entry_items ei
            JOIN entry_records er ON er.record_id = ei.record_id
            JOIN tourists t ON t.user_id = er.user_id
            WHERE er.event_id = {event_id}
            AND er.entry_date = '{today}'
            AND ei.departure_time IS NULL
            AND ei.arrival_time < NOW() - INTERVAL '4 hours'
            LIMIT 5
        """
        long_stay_visitors = await execute_raw_sql(long_stay_query)
        
        if long_stay_visitors:
            alerts.append({
                "type": "long_stay_visitors",
                "severity": "info",
                "message": f"{len(long_stay_visitors)} visitor(s) inside for more than 4 hours",
                "data": {"visitors": long_stay_visitors}
            })
        
        return {
            "success": True,
            "alerts": alerts,
            "alert_count": len(alerts),
            "timestamp": now.isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error fetching security alerts: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch security alerts: {str(e)}"
        )
