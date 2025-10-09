-- =========================================================
-- ENUM TYPES
-- =========================================================

DO $$ BEGIN
    CREATE TYPE unique_id_type_enum AS ENUM ('aadhaar', 'passport', 'college_id', 'other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE entry_type_enum AS ENUM ('normal', 'bypass', 'manual');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- =========================================================
-- EVENTS
-- =========================================================

CREATE TABLE IF NOT EXISTS events (
    event_id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    event_entries TEXT[] NOT NULL DEFAULT ARRAY['main_gate'],
    location TEXT NOT NULL,
    max_capacity INTEGER,
    entry_rules JSONB DEFAULT '{}'::JSONB, -- e.g. {"requires_qr": true}
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_active ON events (is_active);
CREATE INDEX IF NOT EXISTS idx_events_dates ON events (start_date, end_date);


-- =========================================================
-- TOURISTS (VISITORS / GROUPS / INSTITUTIONS)
-- =========================================================

CREATE TABLE IF NOT EXISTS tourists (
    user_id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    unique_id_type unique_id_type_enum NOT NULL,
    unique_id TEXT NOT NULL,
    is_student BOOLEAN NOT NULL DEFAULT FALSE,
    is_group BOOLEAN NOT NULL DEFAULT FALSE,   -- ✅ identifies institute/group vs individual
    group_count INTEGER DEFAULT 1 CHECK (group_count >= 1),  -- ✅ number of members if group
    extra_info JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (unique_id_type, unique_id)
);

CREATE INDEX IF NOT EXISTS idx_tourists_unique_id ON tourists (unique_id_type, unique_id);
CREATE INDEX IF NOT EXISTS idx_tourists_is_group ON tourists (is_group);


-- =========================================================
-- TOURIST META (VPS Storage, QR, Image, etc.)
-- =========================================================

CREATE TABLE IF NOT EXISTS tourist_meta (
    meta_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES tourists(user_id) ON DELETE CASCADE,
    qr_code TEXT UNIQUE, -- could store VPS path like 'https://vps.domain.com/qr/123.png'
    image_path TEXT, -- main face image or folder path
    extra_data JSONB DEFAULT '{}'::JSONB, -- e.g. {"face_img": "url", "qr": "url"}
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tourist_meta_user_id ON tourist_meta (user_id);


-- =========================================================
-- ENTRY RECORDS
-- =========================================================

CREATE TABLE IF NOT EXISTS entry_records (
    record_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES tourists(user_id) ON DELETE CASCADE,
    event_id BIGINT NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    time_logs JSONB NOT NULL DEFAULT '[]'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, event_id, entry_date)
);

CREATE INDEX IF NOT EXISTS idx_entry_records_user_event_date
    ON entry_records (user_id, event_id, entry_date);


-- =========================================================
-- ENTRY ITEMS
-- =========================================================

CREATE TABLE IF NOT EXISTS entry_items (
    item_id BIGSERIAL PRIMARY KEY,
    record_id BIGINT NOT NULL REFERENCES entry_records(record_id) ON DELETE CASCADE,
    entry_point TEXT NOT NULL,
    arrival_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    departure_time TIMESTAMPTZ,
    duration INTERVAL,
    entry_type entry_type_enum NOT NULL DEFAULT 'normal',
    bypass_reason TEXT,
    approved_by_uid UUID,  -- Supabase auth.uid for security users
    metadata JSONB DEFAULT '{}'::JSONB
);

CREATE INDEX IF NOT EXISTS idx_entry_items_record_id ON entry_items (record_id);
CREATE INDEX IF NOT EXISTS idx_entry_items_entry_point ON entry_items (entry_point);
CREATE INDEX IF NOT EXISTS idx_entry_items_entry_type ON entry_items (entry_type);


-- =========================================================
-- STAFF PROFILES (Security / Admins / Organizers)
-- =========================================================

CREATE TABLE IF NOT EXISTS staff_profiles (
    uid UUID PRIMARY KEY,  -- Supabase auth.uid
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('security', 'admin', 'organizer')),
    metadata JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_staff_profiles_role ON staff_profiles (role);


-- =========================================================
-- SYSTEM LOGS (Audit Trail)
-- =========================================================

CREATE TABLE IF NOT EXISTS system_logs (
    log_id BIGSERIAL PRIMARY KEY,
    actor_uid UUID REFERENCES staff_profiles(uid),
    action TEXT NOT NULL,
    details JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_system_logs_actor_uid ON system_logs (actor_uid);


-- =========================================================
-- TRIGGER: Validate entry_point exists in event_entries
-- =========================================================

CREATE OR REPLACE FUNCTION validate_entry_point()
RETURNS TRIGGER AS $$
DECLARE
    valid_points TEXT[];
BEGIN
    SELECT e.event_entries INTO valid_points
    FROM events e
    JOIN entry_records r ON r.event_id = e.event_id
    WHERE r.record_id = NEW.record_id;

    IF NOT (NEW.entry_point = ANY(valid_points)) THEN
        RAISE EXCEPTION 'Invalid entry_point "%". Must be one of %', NEW.entry_point, valid_points;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_entry_point ON entry_items;

CREATE TRIGGER trg_validate_entry_point
BEFORE INSERT OR UPDATE ON entry_items
FOR EACH ROW
EXECUTE FUNCTION validate_entry_point();

-- ✅ FINAL VERSION COMPLETE
