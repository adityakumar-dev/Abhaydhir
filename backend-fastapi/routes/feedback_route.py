from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime, timedelta
from collections import defaultdict
from utils.supabase.supabase import supabaseAdmin
import hashlib
import os
import logging

try:
    import redis
    _redis_client = redis.Redis(
        host=os.getenv("REDIS_HOST", "localhost"),
        port=int(os.getenv("REDIS_PORT", 6379)),
        db=int(os.getenv("REDIS_DB", 0)),
        password=os.getenv("REDIS_PASSWORD", None),
        decode_responses=True,
        socket_connect_timeout=2,
        socket_timeout=2,
    )
    _redis_client.ping()
    _use_redis = True
    logging.info("[RateLimit] Redis connected at %s:%s", os.getenv("REDIS_HOST", "localhost"), os.getenv("REDIS_PORT", 6379))
except Exception as _e:
    _use_redis = False
    _redis_client = None
    logging.warning("[RateLimit] Redis unavailable (%s) — falling back to in-memory store", _e)

# Fallback in-memory store (single-process only)
_memory_store: dict = {}

router = APIRouter()


# ─── Helpers ────────────────────────────────────────────────────────────────

def get_client_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def generate_device_hash(ip: str, user_agent: str, event_id: int) -> str:
    """Deterministic hash that identifies a device+event combination"""
    data = f"{ip}:{user_agent}:{event_id}"
    return hashlib.sha256(data.encode()).hexdigest()


def check_rate_limit(key: str, max_attempts: int = 3, window_minutes: int = 60) -> bool:
    """
    Check and increment rate limit counter.
    Uses Redis sliding window if available, falls back to in-memory list.
    Returns True if the request is allowed, False if limit exceeded.
    """
    if _use_redis and _redis_client:
        try:
            pipe = _redis_client.pipeline()
            now_ms = int(datetime.utcnow().timestamp() * 1000)
            window_ms = window_minutes * 60 * 1000
            cutoff = now_ms - window_ms

            # Sliding window using a sorted set: member=timestamp, score=timestamp
            pipe.zremrangebyscore(key, "-inf", cutoff)
            pipe.zcard(key)
            pipe.zadd(key, {str(now_ms): now_ms})
            pipe.expire(key, window_minutes * 60)
            results = pipe.execute()

            count_before_add = results[1]
            return count_before_add < max_attempts
        except Exception as e:
            logging.warning("[RateLimit] Redis error during check, using memory fallback: %s", e)
            # Fall through to memory fallback

    # In-memory fallback
    now = datetime.utcnow()
    window = timedelta(minutes=window_minutes)
    _memory_store[key] = [
        t for t in _memory_store.get(key, [])
        if now - t < window
    ]
    if len(_memory_store[key]) >= max_attempts:
        return False
    _memory_store[key].append(now)
    return True


# ─── Request Models ──────────────────────────────────────────────────────────

class FeedbackAnswer(BaseModel):
    question_id: int
    answer_number: Optional[float] = None
    answer_text: Optional[str] = Field(None, max_length=2000)

    @validator("answer_text", always=True)
    def at_least_one_value(cls, v, values):
        if v is None and values.get("answer_number") is None:
            raise ValueError("Either answer_number or answer_text must be provided")
        return v


class SubmitFeedbackRequest(BaseModel):
    answers: List[FeedbackAnswer]
    device_fingerprint: Optional[str] = None  # Optional browser-side fingerprint


# ─── Routes ─────────────────────────────────────────────────────────────────

@router.get("/event/{event_id}/questions")
async def get_event_questions(event_id: int):
    """
    Fetch active feedback questions for an event.
    Call this endpoint first to build the feedback form on the frontend.
    """
    try:
        event_resp = (
            supabaseAdmin.table("events")
            .select("event_id, name, is_active")
            .eq("event_id", event_id)
            .single()
            .execute()
        )
        if not event_resp.data:
            raise HTTPException(status_code=404, detail="Event not found")
        if not event_resp.data.get("is_active"):
            raise HTTPException(status_code=403, detail="Feedback is not open for this event")

        questions_resp = (
            supabaseAdmin.table("feedback_questions")
            .select("question_id, question_text, question_type, is_required, display_order, min_value, max_value")
            .eq("event_id", event_id)
            .eq("is_active", True)
            .order("display_order")
            .execute()
        )

        return {
            "event_id": event_id,
            "event_name": event_resp.data.get("name"),
            "questions": questions_resp.data or []
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching questions: {str(e)}")


@router.post("/event/{event_id}/submit")
async def submit_feedback(event_id: int, body: SubmitFeedbackRequest, request: Request):
    """
    Submit anonymous feedback for an event.

    Flow:
      1. Verify event exists and is active
      2. Fetch active questions for this event
      3. Validate all required questions are answered, types and ranges match
      4. Spam prevention (IP rate limit + device-hash 24h cooldown)
      5. Insert feedback_session record
      6. Bulk insert feedback_answers
    """
    try:
        client_ip = get_client_ip(request)
        user_agent = request.headers.get("User-Agent", "")
        device_hash = body.device_fingerprint or generate_device_hash(client_ip, user_agent, event_id)

        # ── Step 1: Verify event ─────────────────────────────────────────
        event_resp = (
            supabaseAdmin.table("events")
            .select("event_id, is_active")
            .eq("event_id", event_id)
            .single()
            .execute()
        )
        if not event_resp.data:
            raise HTTPException(status_code=404, detail="Event not found")
        if not event_resp.data.get("is_active"):
            raise HTTPException(status_code=403, detail="Feedback is not open for this event")

        # ── Step 2: Fetch active questions ───────────────────────────────
        questions_resp = (
            supabaseAdmin.table("feedback_questions")
            .select("question_id, question_type, is_required, min_value, max_value")
            .eq("event_id", event_id)
            .eq("is_active", True)
            .execute()
        )
        if not questions_resp.data:
            raise HTTPException(status_code=400, detail="No active questions found for this event")

        questions_map = {q["question_id"]: q for q in questions_resp.data}
        answer_map = {a.question_id: a for a in body.answers}

        # ── Step 3: Validate answers ─────────────────────────────────────
        # Check all required questions are answered
        missing_required = [
            qid for qid, q in questions_map.items()
            if q["is_required"] and qid not in answer_map
        ]
        if missing_required:
            raise HTTPException(
                status_code=422,
                detail=f"Missing answers for required questions: {missing_required}"
            )

        # Validate each answer against its question type and range
        for q_id, answer in answer_map.items():
            if q_id not in questions_map:
                raise HTTPException(
                    status_code=422,
                    detail=f"Question {q_id} does not belong to this event"
                )
            q = questions_map[q_id]

            if q["question_type"] == "rating":
                if answer.answer_number is None:
                    raise HTTPException(
                        status_code=422,
                        detail=f"Question {q_id} expects a numeric rating"
                    )
                min_v = q.get("min_value") or 1
                max_v = q.get("max_value") or 5
                if not (min_v <= answer.answer_number <= max_v):
                    raise HTTPException(
                        status_code=422,
                        detail=f"Rating for question {q_id} must be between {min_v} and {max_v}"
                    )

            elif q["question_type"] == "text":
                if not answer.answer_text or not answer.answer_text.strip():
                    raise HTTPException(
                        status_code=422,
                        detail=f"Question {q_id} expects a text answer"
                    )

        # ── Step 4: Spam prevention ──────────────────────────────────────
        # 4a. IP-based rate limit: max 3 submissions per hour
        if not check_rate_limit(f"fb:{client_ip}", max_attempts=3, window_minutes=60):
            raise HTTPException(
                status_code=429,
                detail="Too many submissions from your network. Please try again later."
            )

        # 4b. Device hash: same device cannot submit for same event within 24h
        one_day_ago = (datetime.utcnow() - timedelta(hours=24)).isoformat()
        duplicate = (
            supabaseAdmin.table("feedback_sessions")
            .select("session_id")
            .eq("event_id", event_id)
            .eq("device_info", device_hash)
            .gte("submitted_at", one_day_ago)
            .execute()
        )
        if duplicate.data:
            raise HTTPException(
                status_code=409,
                detail="You have already submitted feedback for this event. Please wait 24 hours."
            )

        # ── Step 5: Create feedback_session ─────────────────────────────
        session_result = (
            supabaseAdmin.table("feedback_sessions")
            .insert({
                "event_id": event_id,
                "device_info": device_hash,
                "submitted_at": datetime.utcnow().isoformat()
            })
            .execute()
        )
        if not session_result.data:
            raise HTTPException(status_code=500, detail="Failed to create feedback session")

        session_id = session_result.data[0]["session_id"]

        # ── Step 6: Bulk insert feedback_answers ────────────────────────
        answers_payload = [
            {
                "session_id": session_id,
                "question_id": answer.question_id,
                "answer_number": answer.answer_number,
                "answer_text": answer.answer_text,
                "answered_at": datetime.utcnow().isoformat()
            }
            for answer in body.answers
            if answer.question_id in questions_map
        ]

        if answers_payload:
            answers_result = (
                supabaseAdmin.table("feedback_answers")
                .insert(answers_payload)
                .execute()
            )
            if not answers_result.data:
                raise HTTPException(status_code=500, detail="Failed to save feedback answers")

        return {
            "success": True,
            "message": "Thank you! Your feedback has been submitted.",
            "session_id": session_id
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error submitting feedback: {str(e)}")


@router.get("/event/{event_id}/stats")
async def get_event_feedback_stats(event_id: int):
    """
    Get aggregated feedback statistics per question for an event.
    - Rating questions: average + distribution
    - Text questions: list of all responses
    """
    try:
        questions_resp = (
            supabaseAdmin.table("feedback_questions")
            .select("question_id, question_text, question_type, min_value, max_value")
            .eq("event_id", event_id)
            .eq("is_active", True)
            .order("display_order")
            .execute()
        )
        if not questions_resp.data:
            return {"event_id": event_id, "total_sessions": 0, "questions": []}

        # Total sessions
        sessions_resp = (
            supabaseAdmin.table("feedback_sessions")
            .select("session_id")
            .eq("event_id", event_id)
            .execute()
        )
        total_sessions = len(sessions_resp.data) if sessions_resp.data else 0
        session_ids = [s["session_id"] for s in (sessions_resp.data or [])]

        if not session_ids:
            return {
                "event_id": event_id,
                "total_sessions": 0,
                "questions": [
                    {"question_id": q["question_id"], "question_text": q["question_text"],
                     "type": q["question_type"], "total_answers": 0}
                    for q in questions_resp.data
                ]
            }

        # All answers for these sessions
        answers_resp = (
            supabaseAdmin.table("feedback_answers")
            .select("question_id, answer_number, answer_text")
            .in_("session_id", session_ids)
            .execute()
        )

        answers_by_question = defaultdict(list)
        for a in (answers_resp.data or []):
            answers_by_question[a["question_id"]].append(a)

        results = []
        for q in questions_resp.data:
            qid = q["question_id"]
            q_answers = answers_by_question.get(qid, [])

            if q["question_type"] == "rating":
                nums = [a["answer_number"] for a in q_answers if a["answer_number"] is not None]
                min_v = q.get("min_value") or 1
                max_v = q.get("max_value") or 5
                distribution = {i: 0 for i in range(int(min_v), int(max_v) + 1)}
                for n in nums:
                    key = int(n)
                    if key in distribution:
                        distribution[key] += 1
                results.append({
                    "question_id": qid,
                    "question_text": q["question_text"],
                    "type": "rating",
                    "total_answers": len(nums),
                    "average": round(sum(nums) / len(nums), 2) if nums else 0,
                    "distribution": distribution
                })

            elif q["question_type"] == "text":
                texts = [a["answer_text"] for a in q_answers if a["answer_text"]]
                results.append({
                    "question_id": qid,
                    "question_text": q["question_text"],
                    "type": "text",
                    "total_answers": len(texts),
                    "responses": texts
                })

        return {
            "event_id": event_id,
            "total_sessions": total_sessions,
            "questions": results
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving feedback stats: {str(e)}")