-- ============================================================
-- RPC: get_event_summary
-- Simple summary stats for an event — no entry_items dependency.
--
-- Parameters:
--   event_id_param  BIGINT  – event to summarise
--
-- Returns: single JSON object with:
--   event_id, total_registered, registration_counts (per date),
--   entry_counts (unique per date from entry_records only),
--   currently_inside (unique total across all event dates),
--   entries_by_date  (unique entries per date, same source),
--   feedback_count
--
-- entry_records unique constraint (user_id, event_id, entry_date)
-- guarantees COUNT(*) = unique visitors per date — no entry_items needed.
-- ============================================================

DROP FUNCTION IF EXISTS get_event_summary(BIGINT);

CREATE OR REPLACE FUNCTION get_event_summary(event_id_param BIGINT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    -- Event dates — update these if the event dates change
    v_event_dates DATE[] := ARRAY['2026-02-27', '2026-02-28', '2026-03-01']::DATE[];
BEGIN
    SELECT json_build_object(

        'event_id', event_id_param,

        -- ── Total Registered (all dates) ──────────────────────────────
        'total_registered',
        (
            SELECT COUNT(*)
            FROM tourists
            WHERE registered_event_id = event_id_param
        ),

        -- ── Registration Counts Per Date ──────────────────────────────
        -- How many tourists registered for each event date
        'registration_counts',
        (
            SELECT COALESCE(json_object_agg(valid_date, count), '{}'::json)
            FROM (
                SELECT
                    valid_date,
                    COUNT(*) AS count
                FROM tourists
                WHERE registered_event_id = event_id_param
                  AND valid_date = ANY(v_event_dates)
                GROUP BY valid_date
                ORDER BY valid_date
            ) sub
        ),

        -- ── Unique Entry Counts Per Date ──────────────────────────────
        -- One entry_record per (user, event, date) due to unique constraint
        -- → COUNT(*) per date = unique visitors that day
        'entry_counts',
        (
            SELECT COALESCE(json_object_agg(entry_date, count), '{}'::json)
            FROM (
                SELECT
                    entry_date,
                    COUNT(*) AS count
                FROM entry_records
                WHERE event_id = event_id_param
                  AND entry_date = ANY(v_event_dates)
                GROUP BY entry_date
                ORDER BY entry_date
            ) sub
        ),

        -- ── Total Unique Entries Across All Event Dates ───────────────
        -- Previously "currently_inside" via entry_items — now pure
        -- entry_records: each row is already unique per person per day
        'currently_inside',
        (
            SELECT COUNT(*)
            FROM entry_records
            WHERE event_id = event_id_param
              AND entry_date = ANY(v_event_dates)
        ),

        -- ── Unique Entries Per Date (detailed breakdown) ──────────────
        -- Same source as entry_counts above; exposed as ordered array
        -- for easy chart rendering
        'entries_by_date',
        (
            SELECT COALESCE(
                json_agg(
                    json_build_object(
                        'date',          entry_date,
                        'unique_entries', count
                    )
                    ORDER BY entry_date
                ),
                '[]'::json
            )
            FROM (
                SELECT
                    entry_date,
                    COUNT(*) AS count
                FROM entry_records
                WHERE event_id = event_id_param
                  AND entry_date = ANY(v_event_dates)
                GROUP BY entry_date
            ) sub
        ),

        -- ── Feedback Count ────────────────────────────────────────────
        'feedback_count',
        (
            SELECT COUNT(*)
            FROM feedback_sessions
            WHERE event_id = event_id_param
        )

    ) INTO result;

    RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_event_summary(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_event_summary(BIGINT) TO anon;
