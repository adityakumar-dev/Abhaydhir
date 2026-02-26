-- ============================================================
-- RPC: GET_TOURIST_COMPLETE
-- ============================================================
-- Single comprehensive call to get all tourist data
-- Includes: tourist profile, today's entries, historical entries
-- Input: user_id, event_id (optional)
-- Output: Complete tourist record with entry history in one call

CREATE OR REPLACE FUNCTION get_tourist_complete(
  p_user_id BIGINT,
  p_event_id BIGINT DEFAULT 1
)
RETURNS TABLE (
  -- Tourist Profile
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
  
  -- Tourist Media
  qr_code TEXT,
  image_path TEXT,
  unique_id_path TEXT,
  
  -- Today's Entry Summary
  has_entry_today BOOLEAN,
  entry_record_id BIGINT,
  today_entry_count INTEGER,
  today_open_entries INTEGER,
  last_entry_time TIMESTAMP WITH TIME ZONE,
  
  -- Today's Entry Items (JSON array of all entries)
  today_entries JSONB,
  
  -- Historical Entry Summary (last 10 days)
  entry_history JSONB,
  
  -- Metadata
  message TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH tourist_profile AS (
    -- Get tourist details
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
  today_record AS (
    -- Get today's entry record
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
      AND er.entry_date = CURRENT_DATE
    GROUP BY er.record_id, er.entry_date
  ),
  today_items AS (
    -- Get all entry items for today with metadata
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
      AND er.entry_date = CURRENT_DATE
  ),
  history_records AS (
    -- Get last 10 days of entry history
    SELECT
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
    WHERE er.user_id = p_user_id 
      AND er.event_id = p_event_id 
      AND er.entry_date < CURRENT_DATE
    LIMIT 10
  )
  SELECT
    -- Tourist Profile
    tp.user_id,
    tp.name,
    tp.phone,
    tp.unique_id_type,
    tp.unique_id,
    tp.is_student,
    tp.is_group,
    tp.group_count,
    tp.valid_date,
    tp.registered_event_id,
    tp.created_at,
    
    -- Tourist Media
    tp.qr_code,
    tp.image_path,
    tp.unique_id_path,
    
    -- Today's Entry Summary
    CASE WHEN tr.record_id IS NOT NULL THEN TRUE ELSE FALSE END as has_entry_today,
    tr.record_id,
    COALESCE(tr.entry_count, 0)::INTEGER,
    COALESCE(tr.open_entries, 0)::INTEGER,
    tr.last_arrival,
    
    -- Today's Entry Items
    COALESCE(ti.items, '[]'::jsonb) as today_entries,
    
    -- Historical Entries
    COALESCE(hr.history, '[]'::jsonb) as entry_history,
    
    -- Message
    CASE 
      WHEN tp.user_id IS NULL THEN 'Tourist not found'
      WHEN tr.record_id IS NOT NULL AND tr.open_entries > 0 THEN 'Inside (has open entry)'
      WHEN tr.record_id IS NOT NULL THEN 'Has entries today'
      ELSE 'No entries today'
    END as message
  FROM tourist_profile tp
  LEFT JOIN today_record tr ON tr.record_id IS NOT NULL
  LEFT JOIN today_items ti ON TRUE
  LEFT JOIN history_records hr ON TRUE;
  
  -- If no tourist found, return empty response
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
      'Tourist not found' as message;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_tourist_complete(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_tourist_complete(BIGINT, BIGINT) TO anon;
