-- ============================================================
-- RPC: get_tourists_by_event
-- Replaces the multi-query Python logic in tourist_route.py.
-- Returns paginated tourists with per-tourist entry status
-- AND aggregate statistics in a single round-trip.
--
-- Parameters:
--   p_event_id    – event to query
--   p_filter_date – valid_date filter (which registration dates to show)
--   p_today       – IST date from Python (used for entry status checks)
--   p_limit       – page size  (default 20)
--   p_offset      – page start (default 0)
--   p_only_active – if TRUE, return only tourists currently inside
--   p_search      – optional name substring search (case-insensitive)
-- ============================================================

DROP FUNCTION IF EXISTS get_tourists_by_event(BIGINT, DATE, DATE, INT, INT, BOOLEAN);
DROP FUNCTION IF EXISTS get_tourists_by_event(BIGINT, DATE, DATE, INT, INT, BOOLEAN, TEXT);

CREATE OR REPLACE FUNCTION get_tourists_by_event(
    p_event_id    BIGINT,
    p_filter_date DATE,
    p_today       DATE    DEFAULT CURRENT_DATE,
    p_limit       INT     DEFAULT 20,
    p_offset      INT     DEFAULT 0,
    p_only_active BOOLEAN DEFAULT FALSE,
    p_search      TEXT    DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSON;
BEGIN
    WITH

    -- ── 1. All tourists for this event on the requested date ─────────────────
    all_tourists AS (
        SELECT
            t.*,
            CASE WHEN t.is_group THEN COALESCE(t.group_count, 1) ELSE 1 END AS member_count
        FROM tourists t
        WHERE t.registered_event_id = p_event_id
          AND t.valid_date           = p_filter_date          AND (p_search IS NULL OR t.name ILIKE '%' || p_search || '%')    ),

    -- ── 2. Today's entry records (one per user, for this event) ──────────────
    today_records AS (
        SELECT er.record_id, er.user_id
        FROM entry_records er
        WHERE er.event_id   = p_event_id
          AND er.entry_date  = p_today
          AND er.user_id    IN (SELECT user_id FROM all_tourists)
    ),

    -- ── 3. All entry items for today's records ───────────────────────────────
    today_items AS (
        SELECT tr.user_id, ei.*
        FROM today_records tr
        JOIN entry_items ei ON ei.record_id = tr.record_id
    ),

    -- ── 4. Per-tourist entry status ───────────────────────────────────────────
    tourist_status AS (
        SELECT
            at.user_id,
            at.member_count,
            at.is_group,
            at.group_count,
            (tr.record_id IS NOT NULL)                                           AS has_entry_today,
            (COUNT(ti.item_id) FILTER (WHERE ti.departure_time IS NULL) > 0)     AS is_currently_inside,
            COUNT(ti.item_id)                                                     AS total_entries_today,
            COUNT(ti.item_id) FILTER (WHERE ti.departure_time IS NULL)           AS open_entries
        FROM all_tourists at
        LEFT JOIN today_records tr ON tr.user_id = at.user_id
        LEFT JOIN today_items   ti ON ti.user_id = at.user_id
        GROUP BY at.user_id, at.member_count, at.is_group, at.group_count, tr.record_id
    ),

    -- ── 5. Aggregate statistics (all tourists, unfiltered by pagination) ─────
    stats AS (
        SELECT
            COUNT(*)                                               AS total_tourist_registrations,
            COUNT(*) FILTER (WHERE NOT COALESCE(is_group, FALSE)) AS total_individual_registrations,
            COUNT(*) FILTER (WHERE COALESCE(is_group, FALSE))     AS total_group_registrations,
            COALESCE(SUM(member_count), 0)                        AS total_members,
            COUNT(*) FILTER (WHERE has_entry_today)               AS with_entry_today_registrations,
            COALESCE(SUM(CASE WHEN has_entry_today     THEN member_count ELSE 0 END), 0) AS with_entry_today_members,
            COUNT(*) FILTER (WHERE is_currently_inside)           AS currently_inside_registrations,
            COALESCE(SUM(CASE WHEN is_currently_inside THEN member_count ELSE 0 END), 0) AS currently_inside_members
        FROM tourist_status
    ),

    -- ── 6. Filtered set — apply only_active before pagination ────────────────
    filtered AS (
        SELECT user_id
        FROM tourist_status
        WHERE (NOT p_only_active OR is_currently_inside)
    ),

    -- ── 7. Current page IDs (ordered, paginated) ─────────────────────────────
    page_ids AS (
        SELECT user_id
        FROM filtered
        ORDER BY user_id DESC
        LIMIT  p_limit
        OFFSET p_offset
    ),

    -- ── 8. Enrich page tourists with full columns + today_entry object ────────
    page_data AS (
        SELECT
            to_jsonb(t) ||
            jsonb_build_object(
                'today_entry', jsonb_build_object(
                    'has_entry_today',     ts.has_entry_today,
                    'is_currently_inside', ts.is_currently_inside,
                    'total_entries_today', ts.total_entries_today,
                    'open_entries',        ts.open_entries,
                    'entry_record', (
                        SELECT to_jsonb(er)
                        FROM entry_records er
                        WHERE er.user_id    = t.user_id
                          AND er.event_id   = p_event_id
                          AND er.entry_date  = p_today
                        LIMIT 1
                    ),
                    'entry_items', COALESCE(
                        (SELECT jsonb_agg(to_jsonb(ei) ORDER BY ei.arrival_time ASC)
                         FROM today_records tr
                         JOIN entry_items   ei ON ei.record_id = tr.record_id
                         WHERE tr.user_id = t.user_id),
                        '[]'::jsonb
                    ),
                    'last_entry', (
                        SELECT to_jsonb(ei)
                        FROM today_records tr
                        JOIN entry_items   ei ON ei.record_id = tr.record_id
                        WHERE tr.user_id = t.user_id
                        ORDER BY ei.arrival_time DESC
                        LIMIT 1
                    )
                )
            ) AS row_data
        FROM tourists t
        JOIN page_ids       pi ON pi.user_id = t.user_id
        JOIN tourist_status ts ON ts.user_id = t.user_id
        ORDER BY t.user_id DESC
    )

    SELECT json_build_object(
        'tourists',   COALESCE((SELECT jsonb_agg(pd.row_data) FROM page_data pd), '[]'::jsonb),
        'statistics', (SELECT to_jsonb(s) FROM stats s),
        'pagination', json_build_object(
            'limit',  p_limit,
            'offset', p_offset,
            'count',  (SELECT COUNT(*) FROM page_ids),
            'total',  (SELECT COUNT(*) FROM filtered),
            'date',   p_filter_date::text,
            'search', p_search
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_tourists_by_event(BIGINT, DATE, DATE, INT, INT, BOOLEAN, TEXT)
    TO anon, authenticated, service_role;
