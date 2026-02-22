from typing import Optional, List, Any
from datetime import datetime, date, timedelta
from uuid import UUID
from pydantic import BaseModel, Field

class EntryItem(BaseModel):
    item_id: Optional[int] = None
    record_id: int
    entry_point: str
    arrival_time: Optional[datetime] = None
    departure_time: Optional[datetime] = None
    duration: Optional[str] = None  # ISO 8601 duration string or custom
    entry_type: str = 'normal'  # Should match your enum
    bypass_reason: Optional[str] = None
    approved_by_uid: Optional[UUID] = None
    metadata: Optional[dict] = Field(default_factory=dict)

class EntryRecord(BaseModel):
    record_id: Optional[int] = None
    user_id: int
    event_id: int
    entry_date: Optional[date] = None
    time_logs: List[Any] = Field(default_factory=list)
    created_at: Optional[datetime] = None

class Event(BaseModel):
    event_id: Optional[int] = None
    name: str
    description: Optional[str] = None
    start_date: datetime
    end_date: datetime
   
    location: str
    max_capacity: Optional[int] = None
    entry_rules: Optional[dict] = Field(default_factory=dict)
    is_active: bool = True
    metadata: Optional[dict] = Field(default_factory=dict)
    created_at: Optional[datetime] = None
    allowed_guards: Optional[List[UUID]] = Field(default_factory=list)

class StaffProfile(BaseModel):
    uid: UUID
    name: str
    role: str  # Should be one of ['security', 'admin', 'organizer']
    metadata: Optional[dict] = Field(default_factory=dict)
    created_at: Optional[datetime] = None

class SystemLog(BaseModel):
    log_id: Optional[int] = None
    actor_uid: Optional[UUID] = None
    action: str
    details: Optional[dict] = Field(default_factory=dict)
    created_at: Optional[datetime] = None

class TouristMeta(BaseModel):
    meta_id: Optional[int] = None
    user_id: int
    qr_code: Optional[str] = None
    image_path: Optional[str] = None
    extra_data: Optional[dict] = Field(default_factory=dict)
    created_at: Optional[datetime] = None

class Tourist(BaseModel):
    user_id: Optional[int] = None
    name: str
    unique_id_type: str
    unique_id: str
    is_student: bool = False
    is_group: bool = False
    group_count: int = 1
    registered_event_id: Optional[int] = None
    extra_info: Optional[dict] = Field(default_factory=dict)
    # created_at: Optional[datetime] = None
    phone : Optional[str] = None


# CREATE TABLE public.event_feedback (
#   feedback_id BIGSERIAL PRIMARY KEY,

#   event_id BIGINT NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,

#   rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),

#   comment TEXT,

#   -- anonymous session identifier
#   session_id UUID NOT NULL,

#   -- optional fingerprint hash (device/browser hash)
#   fingerprint TEXT,

#   metadata JSONB DEFAULT '{}'::JSONB,

#   submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

#   -- prevent duplicate feedback from same session for same event
#   UNIQUE(event_id, session_id)
# );

class EventFeedback(BaseModel):
    feedback_id: Optional[int] = None
    event_id: int
    rating: int
    comment: Optional[str] = None
    session_id: UUID
    fingerprint: Optional[str] = None
    metadata: Optional[dict] = Field(default_factory=dict)
    submitted_at: Optional[datetime] = None


# CREATE TABLE public.short_links (
#   id BIGSERIAL PRIMARY KEY,
#   short_code TEXT UNIQUE NOT NULL,

#   -- store only JWT token
#   token TEXT NOT NULL,

#   created_at TIMESTAMPTZ DEFAULT NOW(),
#   expires_at TIMESTAMPTZ,
#   click_count INTEGER DEFAULT 0,

#   is_active BOOLEAN DEFAULT TRUE
# );


class ShortLink(BaseModel):
    id: Optional[int] = None
    short_code: str
    token: str
    created_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    click_count: int = 0
    is_active: bool = True