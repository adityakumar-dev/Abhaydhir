-- ============================================================
-- Camera Backend — Database Schema
-- Run this once in your Supabase SQL Editor
-- ============================================================

-- ─── 1. cam_events ──────────────────────────────────────────
-- Every event message received from any camera is stored here.
CREATE TABLE IF NOT EXISTS cam_events (
    id           BIGSERIAL PRIMARY KEY,
    cam          TEXT             NOT NULL,   -- "entry-cam" | "exit-cam"
    event        TEXT             NOT NULL,   -- "enter" | "exit" | "new_entry" | "heartbeat"
    track_id     INTEGER,                     -- null for heartbeat / new_entry
    conf         REAL,                        -- detection confidence, null if not present
    zone         TEXT,                        -- zone name, null if not present
    dwell        REAL,                        -- seconds in frame, only for "exit"
    unique_count INTEGER,                     -- only for "new_entry" and "heartbeat"
    active_count INTEGER,                     -- only for "heartbeat"
    ts           DOUBLE PRECISION NOT NULL,   -- Unix epoch from camera (UTC)
    received_at  TIMESTAMPTZ      DEFAULT now(),
    raw          JSONB            NOT NULL    -- full original data payload
);

CREATE INDEX IF NOT EXISTS idx_cam_events_cam_ts ON cam_events (cam, ts DESC);
CREATE INDEX IF NOT EXISTS idx_cam_events_event  ON cam_events (event);
CREATE INDEX IF NOT EXISTS idx_cam_events_ts     ON cam_events (ts DESC);


-- ─── 2. cam_status ──────────────────────────────────────────
-- One row per camera; upserted on every heartbeat / new_entry.
CREATE TABLE IF NOT EXISTS cam_status (
    cam          TEXT    PRIMARY KEY,
    unique_count INTEGER NOT NULL DEFAULT 0,
    active_count INTEGER NOT NULL DEFAULT 0,
    last_seen    DOUBLE PRECISION NOT NULL DEFAULT 0,
    online       BOOLEAN NOT NULL DEFAULT false
);

-- Seed the known cameras so GET /api/status always returns both rows
INSERT INTO cam_status (cam) VALUES ('entry-cam'), ('exit-cam')
ON CONFLICT (cam) DO NOTHING;


-- ─── 3. hourly_counts ───────────────────────────────────────
-- Incremented on every "new_entry" event — one row per cam/date/hour.
CREATE TABLE IF NOT EXISTS hourly_counts (
    id    BIGSERIAL PRIMARY KEY,
    cam   TEXT     NOT NULL,
    date  DATE     NOT NULL,
    hour  SMALLINT NOT NULL,   -- 0–23 (local server timezone)
    count INTEGER  NOT NULL DEFAULT 0,
    UNIQUE (cam, date, hour)
);

CREATE INDEX IF NOT EXISTS idx_hourly_counts_cam_date ON hourly_counts (cam, date);


-- ─── 4. latest_frames ───────────────────────────────────────
-- Optional: only written when SAVE_FRAMES=true.
CREATE TABLE IF NOT EXISTS latest_frames (
    cam        TEXT PRIMARY KEY,
    path       TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);


-- ============================================================
-- RPC: increment_hourly_count
-- Called by the backend on every "new_entry" event.
-- Uses INSERT … ON CONFLICT DO UPDATE so it's race-safe.
-- ============================================================
CREATE OR REPLACE FUNCTION increment_hourly_count(
    p_cam  TEXT,
    p_date DATE,
    p_hour SMALLINT
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO hourly_counts (cam, date, hour, count)
    VALUES (p_cam, p_date, p_hour, 1)
    ON CONFLICT (cam, date, hour)
    DO UPDATE SET count = hourly_counts.count + 1;
END;
$$;

GRANT EXECUTE ON FUNCTION increment_hourly_count(TEXT, DATE, SMALLINT) TO authenticated;
GRANT EXECUTE ON FUNCTION increment_hourly_count(TEXT, DATE, SMALLINT) TO anon;
GRANT EXECUTE ON FUNCTION increment_hourly_count(TEXT, DATE, SMALLINT) TO service_role;


-- ============================================================
-- Row Level Security
-- Enable RLS and allow the service role (used by supabaseAdmin)
-- to read/write all rows without restriction.
-- ============================================================
ALTER TABLE cam_events     ENABLE ROW LEVEL SECURITY;
ALTER TABLE cam_status     ENABLE ROW LEVEL SECURITY;
ALTER TABLE hourly_counts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE latest_frames  ENABLE ROW LEVEL SECURITY;

-- Service role bypass (supabaseAdmin uses the service role key)
CREATE POLICY "service_role_all_cam_events"
    ON cam_events FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_cam_status"
    ON cam_status FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_hourly_counts"
    ON hourly_counts FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_latest_frames"
    ON latest_frames FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Optional: allow authenticated users to read (for dashboard queries via anon/user tokens)
CREATE POLICY "authenticated_read_cam_events"
    ON cam_events FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_cam_status"
    ON cam_status FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated_read_hourly_counts"
    ON hourly_counts FOR SELECT TO authenticated USING (true);
