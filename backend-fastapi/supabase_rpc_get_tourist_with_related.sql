-- ============================================================
-- RPC: GET_TOURIST_WITH_RELATED
-- ============================================================
-- Advanced RPC to get complete tourist data + all related users with same phone
-- 
-- Flow:
-- 1. Get primary user details + entries
-- 2. Find all users with SAME phone number + SAME event_id
-- 3. For each related user, get their complete data
-- 4. Return combined result as JSONB structure
--
-- Use Case: Family registrations
-- - User registers with phone 9876543210 for Feb 27
-- - Parent registers with SAME phone for Feb 28
-- - Child registers with SAME phone for Mar 1
-- - Single call returns all 3 users' complete data

DROP FUNCTION IF EXISTS get_tourist_with_related(BIGINT, BIGINT);
DROP FUNCTION IF EXISTS get_tourist_with_related(BIGINT, BIGINT, DATE);

CREATE OR REPLACE FUNCTION get_tourist_with_related(
  p_user_id  BIGINT,
  p_event_id BIGINT DEFAULT 1,
  p_date     DATE   DEFAULT CURRENT_DATE  -- pass from Python to avoid UTC mismatch
)
RETURNS TABLE (
  -- Primary user data
  user_id BIGINT,
  name TEXT,
  phone BIGINT,
  unique_id_type TEXT,
  unique_id TEXT,
  is_student BOOLEAN,
  is_group BOOLEAN,
  group_count INTEGER,
  valid_date DATE,
  registered_event_id BIGINT,
  created_at TIMESTAMP WITH TIME ZONE,
  qr_code TEXT,
  image_path TEXT,
  unique_id_path TEXT,
  has_entry_today BOOLEAN,
  entry_record_id BIGINT,
  today_entry_count INTEGER,
  today_open_entries INTEGER,
  last_entry_time TIMESTAMP WITH TIME ZONE,
  today_entries JSONB,
  entry_history JSONB,
  
  -- Related users with same phone (JSONB array)
  related_users JSONB,
  
  -- Summary
  related_count INTEGER,
  message TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH primary_user AS (
    -- Step 1: Get primary user details
    SELECT
      t.user_id,
      t.name,
      t.phone,
      t.unique_id_type,
      t.unique_id,
      t.is_student,
      t.is_group,
      t.group_count,
      t.valid_date,
      t.registered_event_id,
      t.created_at,
      tm.qr_code,
      tm.image_path,
      tm.unique_id_path
    FROM public.tourists t
    LEFT JOIN public.tourist_meta tm ON tm.user_id = t.user_id
    WHERE t.user_id = p_user_id
    LIMIT 1
  ),
  primary_today_record AS (
    -- Get primary user's today entry record
    SELECT
      er.record_id,
      er.entry_date,
      COUNT(ei.item_id)::INTEGER as entry_count,
      SUM(CASE WHEN ei.departure_time IS NULL THEN 1 ELSE 0 END)::INTEGER as open_entries,
      MAX(ei.arrival_time) as last_arrival
    FROM public.entry_records er
    LEFT JOIN public.entry_items ei ON ei.record_id = er.record_id
    WHERE er.user_id = p_user_id 
      AND er.event_id = p_event_id 
      AND er.entry_date = p_date
    GROUP BY er.record_id, er.entry_date
  ),
  primary_today_items AS (
    -- Get primary user's today entry items
    SELECT
      jsonb_agg(
        jsonb_build_object(
          'item_id', ei.item_id,
          'arrival_time', ei.arrival_time,
          'departure_time', ei.departure_time,
          'duration', ei.duration,
          'entry_type', ei.entry_type,
          'bypass_reason', ei.bypass_reason,
          'approved_by_uid', ei.approved_by_uid,
          'metadata', ei.metadata,
          'entry_number', (ei.metadata->>'entry_number')::INT
        )
        ORDER BY ei.arrival_time ASC
      ) as items
    FROM public.entry_records er
    LEFT JOIN public.entry_items ei ON ei.record_id = er.record_id
    WHERE er.user_id = p_user_id 
      AND er.event_id = p_event_id 
      AND er.entry_date = p_date
  ),
  primary_history AS (
    -- Get primary user's historical entries (last 10 days)
    SELECT
      jsonb_agg(
        jsonb_build_object(
          'entry_date', sub.entry_date,
          'record_id', sub.record_id,
          'entry_count', (
            SELECT COUNT(*)::INT 
            FROM public.entry_items ei 
            WHERE ei.record_id = sub.record_id
          ),
          'items', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'item_id', ei.item_id,
                'arrival_time', ei.arrival_time,
                'departure_time', ei.departure_time,
                'duration', ei.duration,
                'entry_type', ei.entry_type,
                'entry_number', (ei.metadata->>'entry_number')::INT
              )
              ORDER BY ei.arrival_time ASC
            )
            FROM public.entry_items ei 
            WHERE ei.record_id = sub.record_id
          )
        )
        ORDER BY sub.entry_date DESC
      ) as history
    FROM (
      SELECT er.record_id, er.entry_date
      FROM public.entry_records er
      WHERE er.user_id = p_user_id 
        AND er.event_id = p_event_id 
        AND er.entry_date <> p_date
      ORDER BY er.entry_date DESC
      LIMIT 10
    ) sub
  ),
  phone_lookup AS (
    -- Step 2: Find all users with SAME phone + SAME event_id (excluding primary)
    SELECT DISTINCT t.user_id
    FROM public.tourists t
    WHERE t.phone = (SELECT phone FROM primary_user LIMIT 1)
      AND t.registered_event_id = p_event_id
      AND t.user_id != p_user_id  -- Exclude primary user
  ),
  related_users_data AS (
    -- Step 3: For each related user, build their complete data structure
    SELECT
      jsonb_agg(
        jsonb_build_object(
          'user_id', pu.user_id,
          'name', pu.name,
          'phone', pu.phone,
          'unique_id_type', pu.unique_id_type,
          'unique_id', pu.unique_id,
          'is_student', pu.is_student,
          'is_group', pu.is_group,
          'group_count', pu.group_count,
          'valid_date', pu.valid_date,
          'registered_event_id', pu.registered_event_id,
          'created_at', pu.created_at,
          'qr_code', pu.qr_code,
          'image_path', pu.image_path,
          'unique_id_path', pu.unique_id_path,
          'has_entry_today', CASE WHEN ptr.record_id IS NOT NULL THEN TRUE ELSE FALSE END,
          'entry_record_id', ptr.record_id,
          'today_entry_count', COALESCE(ptr.entry_count, 0)::INTEGER,
          'today_open_entries', COALESCE(ptr.open_entries, 0)::INTEGER,
          'last_entry_time', ptr.last_arrival,
          'today_entries', COALESCE(pti.items, '[]'::jsonb),
          'entry_history', COALESCE(ph.history, '[]'::jsonb)
        )
        ORDER BY pu.valid_date ASC
      ) as users
    FROM phone_lookup pl
    JOIN public.tourists pu ON pu.user_id = pl.user_id
    LEFT JOIN public.tourist_meta ptm ON ptm.user_id = pu.user_id
    LEFT JOIN (
      SELECT
        er.record_id,
        er.user_id,
        COUNT(ei.item_id)::INTEGER as entry_count,
        SUM(CASE WHEN ei.departure_time IS NULL THEN 1 ELSE 0 END)::INTEGER as open_entries,
        MAX(ei.arrival_time) as last_arrival
      FROM public.entry_records er
      LEFT JOIN public.entry_items ei ON ei.record_id = er.record_id
      WHERE er.event_id = p_event_id 
        AND er.entry_date = p_date
      GROUP BY er.record_id, er.user_id
    ) ptr ON ptr.user_id = pu.user_id
    LEFT JOIN (
      SELECT
        er.user_id,
        jsonb_agg(
          jsonb_build_object(
            'item_id', ei.item_id,
            'arrival_time', ei.arrival_time,
            'departure_time', ei.departure_time,
            'duration', ei.duration,
            'entry_type', ei.entry_type,
            'entry_number', (ei.metadata->>'entry_number')::INT
          )
          ORDER BY ei.arrival_time ASC
        ) as items
      FROM public.entry_records er
      LEFT JOIN public.entry_items ei ON ei.record_id = er.record_id
      WHERE er.event_id = p_event_id 
        AND er.entry_date = p_date
      GROUP BY er.user_id
    ) pti ON pti.user_id = pu.user_id
    LEFT JOIN (
      SELECT
        er.user_id,
        jsonb_agg(
          jsonb_build_object(
            'entry_date', er.entry_date,
            'record_id', er.record_id,
            'entry_count', (
              SELECT COUNT(*)::INT 
              FROM public.entry_items ei 
              WHERE ei.record_id = er.record_id
            ),
            'items', (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'item_id', ei.item_id,
                  'arrival_time', ei.arrival_time,
                  'departure_time', ei.departure_time,
                  'duration', ei.duration,
                  'entry_type', ei.entry_type,
                  'entry_number', (ei.metadata->>'entry_number')::INT
                )
                ORDER BY ei.arrival_time ASC
              )
              FROM public.entry_items ei 
              WHERE ei.record_id = er.record_id
            )
          )
          ORDER BY er.entry_date DESC
        ) as history
      FROM public.entry_records er
      WHERE er.event_id = p_event_id 
        AND er.entry_date <> p_date
      GROUP BY er.user_id
    ) ph ON ph.user_id = pu.user_id
  )
  SELECT
    -- Primary user
    pu.user_id,
    pu.name,
    pu.phone,
    pu.unique_id_type,
    pu.unique_id,
    pu.is_student,
    pu.is_group,
    pu.group_count,
    pu.valid_date,
    pu.registered_event_id,
    pu.created_at,
    pu.qr_code,
    pu.image_path,
    pu.unique_id_path,
    CASE WHEN ptu.record_id IS NOT NULL THEN TRUE ELSE FALSE END as has_entry_today,
    ptu.record_id,
    COALESCE(ptu.entry_count, 0)::INTEGER,
    COALESCE(ptu.open_entries, 0)::INTEGER,
    ptu.last_arrival,
    COALESCE(ptui.items, '[]'::jsonb) as today_entries,
    COALESCE(puh.history, '[]'::jsonb) as entry_history,
    
    -- Related users
    COALESCE(rud.users, '[]'::jsonb) as related_users,
    COALESCE(jsonb_array_length(COALESCE(rud.users, '[]'::jsonb)), 0)::INTEGER as related_count,
    
    -- Message
    CASE 
      WHEN pu.user_id IS NULL THEN 'Primary user not found'
      WHEN jsonb_array_length(COALESCE(rud.users, '[]'::jsonb)) > 0 
        THEN format('Found primary user + %s related users with same phone', jsonb_array_length(rud.users))
      ELSE 'Primary user found, no related users'
    END as message
  FROM primary_user pu
  LEFT JOIN primary_today_record ptu ON ptu.record_id IS NOT NULL
  LEFT JOIN primary_today_items ptui ON TRUE
  LEFT JOIN primary_history puh ON TRUE
  LEFT JOIN related_users_data rud ON TRUE;
  
  -- If primary user not found
  IF NOT FOUND THEN
    RETURN QUERY SELECT
      NULL::BIGINT as user_id,
      NULL::TEXT as name,
      NULL::BIGINT as phone,
      NULL::TEXT as unique_id_type,
      NULL::TEXT as unique_id,
      NULL::BOOLEAN as is_student,
      NULL::BOOLEAN as is_group,
      NULL::INTEGER as group_count,
      NULL::DATE as valid_date,
      NULL::BIGINT as registered_event_id,
      NULL::TIMESTAMP WITH TIME ZONE as created_at,
      NULL::TEXT as qr_code,
      NULL::TEXT as image_path,
      NULL::TEXT as unique_id_path,
      FALSE as has_entry_today,
      NULL::BIGINT as entry_record_id,
      0::INTEGER as today_entry_count,
      0::INTEGER as today_open_entries,
      NULL::TIMESTAMP WITH TIME ZONE as last_entry_time,
      '[]'::jsonb as today_entries,
      '[]'::jsonb as entry_history,
      '[]'::jsonb as related_users,
      0::INTEGER as related_count,
      'Primary user not found' as message;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_tourist_with_related(BIGINT, BIGINT, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_tourist_with_related(BIGINT, BIGINT, DATE) TO anon;
