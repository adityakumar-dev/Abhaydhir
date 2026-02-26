-- ============================================================
-- RPC: VERIFY_QR_CODE
-- ============================================================
-- Fast QR verification with single lookup returning all needed data
-- Input: short_code (from QR), event_id (default 1)
-- Output: tourist details, entry status, validity check
-- Purpose: Low-latency entry verification without multiple queries

CREATE OR REPLACE FUNCTION verify_qr_code(
  p_short_code TEXT,
  p_event_id BIGINT DEFAULT 1,
  p_entry_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  user_id BIGINT,
  name TEXT,
  phone BIGINT,
  valid_date DATE,
  is_group BOOLEAN,
  group_count INTEGER,
  image_path TEXT,
  unique_id_path TEXT,
  qr_code TEXT,
  event_id BIGINT,
  registered_event_id BIGINT,
  is_already_inside BOOLEAN,
  has_entry_today BOOLEAN,
  last_entry_time TIMESTAMP WITH TIME ZONE,
  total_entries_today INTEGER,
  unique_id_type TEXT,
  unique_id TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH qr_lookup AS (
    -- Step 1: Find tourist by short_code from tourist_meta using qr_code column
    SELECT 
      tm.user_id,
      tm.qr_code,
      tm.image_path,
      tm.unique_id_path
    FROM public.tourist_meta tm
    WHERE tm.qr_code = p_short_code
    LIMIT 1
  ),
  tourist_details AS (
    -- Step 2: Get tourist and event details
    SELECT
      t.user_id,
      t.name,
      t.phone,
      t.valid_date,
      t.is_group,
      t.group_count,
      t.registered_event_id,
      t.unique_id_type,
      t.unique_id,
      ql.image_path,
      ql.unique_id_path,
      ql.qr_code
    FROM qr_lookup ql
    JOIN public.tourists t ON t.user_id = ql.user_id
  ),
  entry_status AS (
    -- Step 3: Check today's entry status
    SELECT
      td.user_id,
      er.record_id,
      COUNT(ei.item_id)::INTEGER as total_entries_today,
      MAX(ei.arrival_time) as last_entry_time,
      SUM(CASE WHEN ei.departure_time IS NULL THEN 1 ELSE 0 END)::INTEGER as open_entries
    FROM tourist_details td
    LEFT JOIN public.entry_records er 
      ON er.user_id = td.user_id 
      AND er.event_id = p_event_id 
      AND er.entry_date = p_entry_date
    LEFT JOIN public.entry_items ei 
      ON ei.record_id = er.record_id
    GROUP BY td.user_id, er.record_id
  )
  SELECT
    -- Success checks
    CASE
      WHEN tourist_details.user_id IS NULL THEN FALSE
      WHEN tourist_details.valid_date != p_entry_date THEN FALSE
      ELSE TRUE
    END as success,
    
    -- Message for status
    CASE
      WHEN tourist_details.user_id IS NULL THEN 'Invalid QR code - Tourist not found'
      WHEN tourist_details.valid_date < p_entry_date THEN 'Card expired - valid_date has passed'
      WHEN tourist_details.valid_date > p_entry_date THEN format('Card valid from %s - not yet valid', tourist_details.valid_date)
      WHEN entry_status.open_entries > 0 THEN 'Already inside (has open entry)'
      ELSE 'Ready to enter'
    END as message,
    
    -- Tourist data
    tourist_details.user_id,
    tourist_details.name,
    tourist_details.phone,
    tourist_details.valid_date,
    tourist_details.is_group,
    tourist_details.group_count,
    tourist_details.image_path,
    tourist_details.unique_id_path,
    tourist_details.qr_code,
    p_event_id,
    tourist_details.registered_event_id,
    
    -- Entry status
    CASE WHEN COALESCE(entry_status.open_entries, 0) > 0 THEN TRUE ELSE FALSE END as is_already_inside,
    CASE WHEN entry_status.record_id IS NOT NULL THEN TRUE ELSE FALSE END as has_entry_today,
    entry_status.last_entry_time,
    COALESCE(entry_status.total_entries_today, 0)::INTEGER as total_entries_today,
    
    -- ID verification data
    tourist_details.unique_id_type,
    tourist_details.unique_id
  FROM tourist_details
  LEFT JOIN entry_status ON entry_status.user_id = tourist_details.user_id
  WHERE tourist_details.user_id IS NOT NULL
  LIMIT 1;
  
  -- If no results (invalid QR), return error response
  IF NOT FOUND THEN
    RETURN QUERY SELECT
      FALSE as success,
      'Invalid QR code - not found in system' as message,
      NULL::BIGINT as user_id,
      NULL::TEXT as name,
      NULL::BIGINT as phone,
      NULL::DATE as valid_date,
      NULL::BOOLEAN as is_group,
      NULL::INTEGER as group_count,
      NULL::TEXT as image_path,
      NULL::TEXT as unique_id_path,
      p_short_code as qr_code,
      p_event_id as event_id,
      NULL::BIGINT as registered_event_id,
      FALSE as is_already_inside,
      FALSE as has_entry_today,
      NULL::TIMESTAMP WITH TIME ZONE as last_entry_time,
      0::INTEGER as total_entries_today,
      NULL::TEXT as unique_id_type,
      NULL::TEXT as unique_id;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION verify_qr_code(TEXT, BIGINT, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_qr_code(TEXT, BIGINT, DATE) TO anon;
