-- ============================================================
-- RPC: get_event_analytics
-- Single DB round-trip for complete event analytics dashboard.
--
-- Parameters:
--   p_event_id   BIGINT  – event to analyse
--   p_date       DATE    – the date to analyse (pass from Python to avoid UTC mismatch)
--
-- Returns: single JSONB row with all sections:
--   event_info, crowd_status, today_summary, last_hour,
--   entry_type_breakdown, hourly_distribution, recent_entries,
--   alerts, registrations_summary
-- ============================================================

DROP FUNCTION IF EXISTS get_event_analytics(BIGINT, DATE);

CREATE OR REPLACE FUNCTION get_event_analytics(
    p_event_id   BIGINT,
    p_date       DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    event_info              JSONB,
    crowd_status            JSONB,
    today_summary           JSONB,
    last_hour               JSONB,
    entry_type_breakdown    JSONB,
    hourly_distribution     JSONB,
    recent_entries          JSONB,
    alerts                  JSONB,
    registrations_summary   JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_now               TIMESTAMPTZ := NOW();
    v_one_hour_ago      TIMESTAMPTZ := NOW() - INTERVAL '1 hour';
    v_max_capacity      INT;
    v_event_name        TEXT;
    v_event_location    TEXT;
    v_event_start       DATE;
    v_event_end         DATE;
    v_is_active         BOOLEAN;

    -- crowd
    v_total_inside              INT := 0;
    v_total_people_inside       INT := 0;
    v_groups_inside             INT := 0;
    v_individuals_inside        INT := 0;

    -- today summary
    v_total_unique_visitors     INT := 0;
    v_total_entries             INT := 0;
    v_total_people_count        INT := 0;
    v_total_groups              INT := 0;
    v_total_individuals         INT := 0;
    v_exited_visitors           INT := 0;
    v_avg_visit_duration_sec    FLOAT := 0;

    -- last hour
    v_entries_last_hour         INT := 0;
    v_unique_last_hour          INT := 0;
    v_normal_last_hour          INT := 0;
    v_bypass_last_hour          INT := 0;
    v_manual_last_hour          INT := 0;

    -- registrations (total registered for this date)
    v_total_registered          INT := 0;
    v_total_registered_members  INT := 0;
    v_total_reg_groups          INT := 0;
    v_total_reg_individuals     INT := 0;

    -- alerts
    v_bypass_count_1hr      INT := 0;
    v_long_stay_count       INT := 0;
    v_capacity_pct          FLOAT := 0;

    -- JSON builders
    j_entry_types           JSONB;
    j_hourly                JSONB;
    j_recent                JSONB;
    j_alerts                JSONB := '[]'::JSONB;
    j_long_stay             JSONB;
BEGIN
    -- ── 0. Event info ────────────────────────────────────────────────
    SELECT
        e.name, e.location, e.max_capacity,
        e.start_date::DATE, e.end_date::DATE, e.is_active
    INTO
        v_event_name, v_event_location, v_max_capacity,
        v_event_start, v_event_end, v_is_active
    FROM public.events e
    WHERE e.event_id = p_event_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event % not found', p_event_id;
    END IF;

    -- ── 1. Crowd status (currently inside) ──────────────────────────
    SELECT
        COUNT(DISTINCT er.user_id),
        COALESCE(SUM(CASE WHEN t.is_group THEN t.group_count ELSE 1 END), 0),
        COUNT(DISTINCT CASE WHEN t.is_group     THEN er.user_id END),
        COUNT(DISTINCT CASE WHEN NOT t.is_group THEN er.user_id END)
    INTO
        v_total_inside, v_total_people_inside,
        v_groups_inside, v_individuals_inside
    FROM public.entry_records er
    JOIN public.tourists t ON t.user_id = er.user_id
    WHERE er.event_id = p_event_id
      AND er.entry_date = p_date
      AND EXISTS (
          SELECT 1 FROM public.entry_items ei
          WHERE ei.record_id = er.record_id
            AND ei.departure_time IS NULL
      );

    -- ── 2. Today's summary ───────────────────────────────────────────
    SELECT
        COUNT(DISTINCT er.user_id),
        COUNT(DISTINCT ei.item_id),
        COALESCE(SUM(CASE WHEN t.is_group THEN t.group_count ELSE 1 END), 0),
        COUNT(DISTINCT CASE WHEN t.is_group     THEN er.user_id END),
        COUNT(DISTINCT CASE WHEN NOT t.is_group THEN er.user_id END),
        COUNT(DISTINCT CASE WHEN ei.departure_time IS NOT NULL THEN er.user_id END),
        COALESCE(AVG(EXTRACT(EPOCH FROM ei.duration)), 0)
    INTO
        v_total_unique_visitors, v_total_entries,
        v_total_people_count, v_total_groups, v_total_individuals,
        v_exited_visitors, v_avg_visit_duration_sec
    FROM public.entry_records er
    JOIN public.tourists t ON t.user_id = er.user_id
    LEFT JOIN public.entry_items ei ON ei.record_id = er.record_id
    WHERE er.event_id = p_event_id
      AND er.entry_date = p_date;

    -- ── 3. Last hour ─────────────────────────────────────────────────
    SELECT
        COUNT(DISTINCT ei.item_id),
        COUNT(DISTINCT er.user_id),
        COUNT(DISTINCT CASE WHEN ei.entry_type = 'qr_code_scan' THEN ei.item_id END),
        COUNT(DISTINCT CASE WHEN ei.entry_type = 'bypass'       THEN ei.item_id END),
        COUNT(DISTINCT CASE WHEN ei.entry_type = 'manual_entry' THEN ei.item_id END)
    INTO
        v_entries_last_hour, v_unique_last_hour,
        v_normal_last_hour, v_bypass_last_hour, v_manual_last_hour
    FROM public.entry_items ei
    JOIN public.entry_records er ON er.record_id = ei.record_id
    WHERE er.event_id = p_event_id
      AND ei.arrival_time >= v_one_hour_ago
      AND ei.arrival_time <= v_now;

    -- ── 4. Registrations summary for p_date ─────────────────────────
    SELECT
        COUNT(*),
        COALESCE(SUM(CASE WHEN t.is_group THEN t.group_count ELSE 1 END), 0),
        COUNT(CASE WHEN t.is_group     THEN 1 END),
        COUNT(CASE WHEN NOT t.is_group THEN 1 END)
    INTO
        v_total_registered, v_total_registered_members,
        v_total_reg_groups, v_total_reg_individuals
    FROM public.tourists t
    WHERE t.registered_event_id = p_event_id
      AND t.valid_date = p_date;

    -- ── 5. Entry type breakdown ──────────────────────────────────────
    SELECT COALESCE(jsonb_agg(row_to_json(x)::JSONB), '[]'::JSONB)
    INTO j_entry_types
    FROM (
        SELECT
            COALESCE(ei.entry_type, 'unknown') AS entry_type,
            COUNT(*) AS count,
            ROUND(COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS percentage
        FROM public.entry_items ei
        JOIN public.entry_records er ON er.record_id = ei.record_id
        WHERE er.event_id = p_event_id
          AND er.entry_date = p_date
        GROUP BY ei.entry_type
        ORDER BY count DESC
    ) x;

    -- ── 6. Hourly distribution ───────────────────────────────────────
    SELECT COALESCE(jsonb_agg(row_to_json(x)::JSONB ORDER BY x.hour), '[]'::JSONB)
    INTO j_hourly
    FROM (
        SELECT
            EXTRACT(HOUR FROM ei.arrival_time AT TIME ZONE 'Asia/Kolkata')::INT AS hour,
            COUNT(DISTINCT ei.item_id)   AS entries,
            COUNT(DISTINCT er.user_id)   AS unique_visitors
        FROM public.entry_items ei
        JOIN public.entry_records er ON er.record_id = ei.record_id
        WHERE er.event_id = p_event_id
          AND er.entry_date = p_date
        GROUP BY hour
        ORDER BY hour
    ) x;

    -- ── 7. Recent 10 entries ─────────────────────────────────────────
    SELECT COALESCE(jsonb_agg(row_to_json(x)::JSONB), '[]'::JSONB)
    INTO j_recent
    FROM (
        SELECT
            ei.item_id,
            er.user_id,
            t.name,
            t.phone,
            t.is_group,
            t.group_count,
            ei.arrival_time,
            ei.departure_time,
            ei.entry_type,
            ei.bypass_reason,
            CASE WHEN ei.departure_time IS NULL THEN 'inside' ELSE 'exited' END AS status,
            ROUND(EXTRACT(EPOCH FROM (v_now - ei.arrival_time)) / 60) AS minutes_since_entry
        FROM public.entry_items ei
        JOIN public.entry_records er ON er.record_id = ei.record_id
        JOIN public.tourists t ON t.user_id = er.user_id
        WHERE er.event_id = p_event_id
          AND er.entry_date = p_date
        ORDER BY ei.arrival_time DESC
        LIMIT 10
    ) x;

    -- ── 8. Alerts ────────────────────────────────────────────────────
    -- 8a. Capacity alert
    IF v_max_capacity IS NOT NULL AND v_max_capacity > 0 THEN
        v_capacity_pct := ROUND((v_total_people_inside::FLOAT / v_max_capacity) * 100, 2);
        IF v_capacity_pct >= 90 THEN
            j_alerts := j_alerts || jsonb_build_object(
                'type', 'capacity_critical', 'severity', 'critical',
                'message', format('Capacity at %s%% – Critical', v_capacity_pct),
                'data', jsonb_build_object('current', v_total_people_inside, 'max', v_max_capacity, 'percentage', v_capacity_pct)
            );
        ELSIF v_capacity_pct >= 75 THEN
            j_alerts := j_alerts || jsonb_build_object(
                'type', 'capacity_high', 'severity', 'warning',
                'message', format('Capacity at %s%% – High', v_capacity_pct),
                'data', jsonb_build_object('current', v_total_people_inside, 'max', v_max_capacity, 'percentage', v_capacity_pct)
            );
        END IF;
    END IF;

    -- 8b. High bypass in last hour
    SELECT COUNT(*) INTO v_bypass_count_1hr
    FROM public.entry_items ei
    JOIN public.entry_records er ON er.record_id = ei.record_id
    WHERE er.event_id = p_event_id
      AND er.entry_date = p_date
      AND ei.entry_type = 'bypass'
      AND ei.arrival_time >= v_one_hour_ago;

    IF v_bypass_count_1hr > 10 THEN
        j_alerts := j_alerts || jsonb_build_object(
            'type', 'high_bypass_activity', 'severity', 'warning',
            'message', format('High bypass activity: %s bypasses in last hour', v_bypass_count_1hr),
            'data', jsonb_build_object('bypass_count', v_bypass_count_1hr)
        );
    END IF;

    -- 8c. Long-stay visitors (> 4 hours, still inside)
    SELECT
        COUNT(*),
        COALESCE(jsonb_agg(jsonb_build_object(
            'user_id', er.user_id,
            'name', t.name,
            'arrival_time', ei.arrival_time,
            'hours_inside', ROUND(EXTRACT(EPOCH FROM (v_now - ei.arrival_time)) / 3600, 1)
        )), '[]'::JSONB)
    INTO v_long_stay_count, j_long_stay
    FROM public.entry_items ei
    JOIN public.entry_records er ON er.record_id = ei.record_id
    JOIN public.tourists t ON t.user_id = er.user_id
    WHERE er.event_id = p_event_id
      AND er.entry_date = p_date
      AND ei.departure_time IS NULL
      AND ei.arrival_time < v_now - INTERVAL '4 hours';

    IF v_long_stay_count > 0 THEN
        j_alerts := j_alerts || jsonb_build_object(
            'type', 'long_stay_visitors', 'severity', 'info',
            'message', format('%s visitor(s) inside for more than 4 hours', v_long_stay_count),
            'data', jsonb_build_object('count', v_long_stay_count, 'visitors', j_long_stay)
        );
    END IF;

    -- ── Return all sections ──────────────────────────────────────────
    RETURN QUERY SELECT
        -- event_info
        jsonb_build_object(
            'event_id',    p_event_id,
            'name',        v_event_name,
            'location',    v_event_location,
            'max_capacity',v_max_capacity,
            'start_date',  v_event_start,
            'end_date',    v_event_end,
            'is_active',   v_is_active,
            'query_date',  p_date,
            'generated_at',v_now
        ),
        -- crowd_status
        jsonb_build_object(
            'currently_inside',      COALESCE(v_total_inside, 0),
            'total_people_inside',   COALESCE(v_total_people_inside, 0),
            'groups_inside',         COALESCE(v_groups_inside, 0),
            'individuals_inside',    COALESCE(v_individuals_inside, 0),
            'capacity_percentage',   v_capacity_pct,
            'capacity_status',       CASE
                WHEN v_max_capacity IS NULL THEN 'unknown'
                WHEN v_capacity_pct >= 90   THEN 'critical'
                WHEN v_capacity_pct >= 75   THEN 'high'
                WHEN v_capacity_pct >= 50   THEN 'moderate'
                ELSE 'low'
            END
        ),
        -- today_summary
        jsonb_build_object(
            'total_unique_visitors',   COALESCE(v_total_unique_visitors, 0),
            'total_entries',           COALESCE(v_total_entries, 0),
            'total_people_count',      COALESCE(v_total_people_count, 0),
            'total_groups',            COALESCE(v_total_groups, 0),
            'total_individuals',       COALESCE(v_total_individuals, 0),
            'exited_visitors',         COALESCE(v_exited_visitors, 0),
            'still_inside',            COALESCE(v_total_inside, 0),
            'avg_visit_duration_min',  ROUND((COALESCE(v_avg_visit_duration_sec, 0) / 60)::NUMERIC, 2)
        ),
        -- last_hour
        jsonb_build_object(
            'entries',              COALESCE(v_entries_last_hour, 0),
            'unique_visitors',      COALESCE(v_unique_last_hour, 0),
            'entry_rate_per_min',   ROUND((COALESCE(v_entries_last_hour, 0)::FLOAT / 60)::NUMERIC, 2),
            'qr_scan_entries',      COALESCE(v_normal_last_hour, 0),
            'bypass_entries',       COALESCE(v_bypass_last_hour, 0),
            'manual_entries',       COALESCE(v_manual_last_hour, 0)
        ),
        -- entry_type_breakdown
        COALESCE(j_entry_types, '[]'::JSONB),
        -- hourly_distribution
        COALESCE(j_hourly, '[]'::JSONB),
        -- recent_entries
        COALESCE(j_recent, '[]'::JSONB),
        -- alerts
        COALESCE(j_alerts, '[]'::JSONB),
        -- registrations_summary
        jsonb_build_object(
            'total_registered',         COALESCE(v_total_registered, 0),
            'total_registered_members', COALESCE(v_total_registered_members, 0),
            'total_reg_groups',         COALESCE(v_total_reg_groups, 0),
            'total_reg_individuals',    COALESCE(v_total_reg_individuals, 0),
            'attendance_rate_pct',      CASE
                WHEN COALESCE(v_total_registered, 0) = 0 THEN 0
                ELSE ROUND((v_total_unique_visitors::FLOAT / v_total_registered * 100)::NUMERIC, 2)
            END
        );
END;
$$;

GRANT EXECUTE ON FUNCTION get_event_analytics(BIGINT, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_event_analytics(BIGINT, DATE) TO anon;
