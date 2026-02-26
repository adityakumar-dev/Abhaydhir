from fastapi import APIRouter, HTTPException, Request, Depends, Query
from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime, timedelta
from collections import defaultdict
from utils.supabase.supabase import supabaseAdmin
from utils.supabase.auth import jwt_middleware
import hashlib
import os
import logging

# ─── Redis (shared client) ───────────────────────────────────────────────────
from utils.services.redis_client import redis_client as _redis_client, redis_ok as _use_redis

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

# ─── Admin: paginated sessions list ─────────────────────────────────────────

@router.get("/event/{event_id}/sessions")
async def list_feedback_sessions(
    event_id: int,
    limit:  int  = Query(20, ge=1, le=100),
    offset: int  = Query(0,  ge=0),
    user=Depends(jwt_middleware)
):
    """
    [Admin only] Paginated list of all feedback sessions for an event.
    Each session includes every answer with its question text.
    """
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    try:
        # Questions lookup
        q_resp = (
            supabaseAdmin.table("feedback_questions")
            .select("question_id, question_text, question_type, display_order")
            .eq("event_id", event_id)
            .order("display_order")
            .execute()
        )
        questions_map = {q["question_id"]: q for q in (q_resp.data or [])}

        # Total count
        all_sessions = (
            supabaseAdmin.table("feedback_sessions")
            .select("session_id")
            .eq("event_id", event_id)
            .execute()
        )
        total = len(all_sessions.data) if all_sessions.data else 0

        # Page of sessions
        sessions_resp = (
            supabaseAdmin.table("feedback_sessions")
            .select("session_id, submitted_at, device_info")
            .eq("event_id", event_id)
            .order("submitted_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        sessions = sessions_resp.data or []
        if not sessions:
            return {"event_id": event_id, "total": total, "sessions": [],
                    "pagination": {"limit": limit, "offset": offset, "count": 0}}

        session_ids = [s["session_id"] for s in sessions]

        # All answers for this page
        answers_resp = (
            supabaseAdmin.table("feedback_answers")
            .select("session_id, question_id, answer_number, answer_text, answered_at")
            .in_("session_id", session_ids)
            .execute()
        )
        answers_by_session: dict = defaultdict(list)
        for a in (answers_resp.data or []):
            q = questions_map.get(a["question_id"], {})
            answers_by_session[a["session_id"]].append({
                "question_id":   a["question_id"],
                "question_text": q.get("question_text", ""),
                "question_type": q.get("question_type", ""),
                "answer_number": a["answer_number"],
                "answer_text":   a["answer_text"],
                "answered_at":   a["answered_at"],
            })

        result = []
        for s in sessions:
            sid = s["session_id"]
            result.append({
                "session_id":   sid,
                "submitted_at": s["submitted_at"],
                # truncate device_info hash for display — no raw PII
                "device_ref":   s["device_info"][:12] + "...",
                "answers":      sorted(
                    answers_by_session.get(sid, []),
                    key=lambda x: questions_map.get(x["question_id"], {}).get("display_order", 0)
                ),
            })

        return {
            "event_id": event_id,
            "total":    total,
            "sessions": result,
            "pagination": {"limit": limit, "offset": offset, "count": len(result)},
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing sessions: {str(e)}")


# ─── Admin: CSV export ───────────────────────────────────────────────────────

@router.get("/event/{event_id}/export")
async def export_feedback_csv(
    event_id: int,
    user=Depends(jwt_middleware)
):
    """
    [Admin only] Download all feedback for an event as a CSV file.
    Columns: Session Ref, Submitted At, <one column per question>
    """
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    try:
        import csv, io
        from fastapi.responses import StreamingResponse

        # Event name for filename
        event_resp = (
            supabaseAdmin.table("events")
            .select("name")
            .eq("event_id", event_id)
            .single()
            .execute()
        )
        event_name = (event_resp.data or {}).get("name", f"event_{event_id}")

        # Questions ordered by display_order
        q_resp = (
            supabaseAdmin.table("feedback_questions")
            .select("question_id, question_text, question_type, display_order")
            .eq("event_id", event_id)
            .order("display_order")
            .execute()
        )
        questions = q_resp.data or []
        questions_map = {q["question_id"]: q for q in questions}

        # All sessions
        sessions_resp = (
            supabaseAdmin.table("feedback_sessions")
            .select("session_id, submitted_at")
            .eq("event_id", event_id)
            .order("submitted_at", desc=False)
            .execute()
        )
        sessions = sessions_resp.data or []
        if not sessions:
            raise HTTPException(status_code=404, detail="No feedback submissions found for this event")

        session_ids = [s["session_id"] for s in sessions]

        # All answers
        answers_resp = (
            supabaseAdmin.table("feedback_answers")
            .select("session_id, question_id, answer_number, answer_text")
            .in_("session_id", session_ids)
            .execute()
        )
        answers_by_session: dict = defaultdict(dict)
        for a in (answers_resp.data or []):
            q = questions_map.get(a["question_id"], {})
            value = (
                a["answer_number"]
                if q.get("question_type") == "rating"
                else a["answer_text"]
            )
            answers_by_session[a["session_id"]][a["question_id"]] = value

        # Build CSV
        output = io.StringIO()
        writer = csv.writer(output)

        # Header row
        header = ["Session Ref", "Submitted At"] + [
            f"Q{i+1}: {q['question_text']}" for i, q in enumerate(questions)
        ]
        writer.writerow(header)

        # Data rows
        for s in sessions:
            sid = s["session_id"]
            row = [
                sid,
                s["submitted_at"],
            ]
            for q in questions:
                row.append(answers_by_session.get(sid, {}).get(q["question_id"], ""))
            writer.writerow(row)

        output.seek(0)
        safe_name = event_name.replace(" ", "_")
        filename  = f"feedback_{safe_name}_{datetime.utcnow().strftime('%Y%m%d')}.csv"

        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error exporting feedback: {str(e)}")
# ─── shared helper ────────────────────────────────────────────────────────────

def _fetch_stats_data(event_id: int):
    """
    Internal helper: returns (questions, total_sessions, answers_by_question).
    Raises HTTPException if no questions found.
    """
    questions_resp = (
        supabaseAdmin.table("feedback_questions")
        .select("question_id, question_text, question_type, min_value, max_value, display_order")
        .eq("event_id", event_id)
        .eq("is_active", True)
        .order("display_order")
        .execute()
    )
    if not questions_resp.data:
        return [], 0, {}

    sessions_resp = (
        supabaseAdmin.table("feedback_sessions")
        .select("session_id")
        .eq("event_id", event_id)
        .execute()
    )
    session_ids = [s["session_id"] for s in (sessions_resp.data or [])]
    total_sessions = len(session_ids)

    answers_by_question: dict = defaultdict(list)
    if session_ids:
        answers_resp = (
            supabaseAdmin.table("feedback_answers")
            .select("question_id, answer_number, answer_text, answered_at")
            .in_("session_id", session_ids)
            .execute()
        )
        for a in (answers_resp.data or []):
            answers_by_question[a["question_id"]].append(a)

    return questions_resp.data, total_sessions, answers_by_question


# ─── Stats: overview (averages + recent comments) ─────────────────────────────

@router.get("/event/{event_id}/stats")
async def get_event_feedback_stats(
    event_id: int,
    recent: int = Query(5, ge=1, le=50, description="How many recent text responses to include"),
    user=Depends(jwt_middleware)
):
    """
    [Admin only] Overview stats — designed for a dashboard summary card.
    - Rating questions : average score + full distribution
    - Text questions   : total count + the N most recent responses (default 5)
    For full paginated text responses use /stats/page/{page}
    """
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    try:
        questions, total_sessions, answers_by_question = _fetch_stats_data(event_id)

        if not questions:
            return {"event_id": event_id, "total_sessions": 0, "questions": []}

        if total_sessions == 0:
            return {
                "event_id": event_id,
                "total_sessions": 0,
                "questions": [
                    {"question_id": q["question_id"], "question_text": q["question_text"],
                     "type": q["question_type"], "total_answers": 0}
                    for q in questions
                ],
            }

        results = []
        for q in questions:
            qid      = q["question_id"]
            q_answers = answers_by_question.get(qid, [])

            if q["question_type"] == "rating":
                nums  = [a["answer_number"] for a in q_answers if a["answer_number"] is not None]
                min_v = q.get("min_value") or 1
                max_v = q.get("max_value") or 5
                dist  = {i: 0 for i in range(int(min_v), int(max_v) + 1)}
                for n in nums:
                    k = int(n)
                    if k in dist:
                        dist[k] += 1
                results.append({
                    "question_id":   qid,
                    "question_text": q["question_text"],
                    "type":          "rating",
                    "total_answers": len(nums),
                    "average":       round(sum(nums) / len(nums), 2) if nums else 0,
                    "distribution":  dist,
                })

            elif q["question_type"] == "text":
                # Sort newest first so [:recent] gives the most recent
                sorted_answers = sorted(
                    q_answers,
                    key=lambda a: a.get("answered_at") or "",
                    reverse=True
                )
                texts = [a["answer_text"] for a in sorted_answers if a["answer_text"]]
                results.append({
                    "question_id":        qid,
                    "question_text":      q["question_text"],
                    "type":               "text",
                    "total_answers":      len(texts),
                    "recent_responses":   texts[:recent],
                    "has_more":           len(texts) > recent,
                })

        return {
            "event_id":       event_id,
            "total_sessions": total_sessions,
            "questions":      results,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving feedback stats: {str(e)}")


# ─── Stats: paginated text responses ──────────────────────────────────────────

@router.get("/event/{event_id}/stats/page/{page}")
async def get_event_feedback_stats_page(
    event_id:    int,
    page:        int,
    page_size:   int  = Query(20, ge=1, le=100, description="Responses per page"),
    question_id: Optional[int] = Query(None, description="Filter to a single question"),
    user=Depends(jwt_middleware)
):
    """
    [Admin only] Paginated text responses — for a dedicated 'Responses' table view.
    Optionally filter to a single question_id.
    Rating questions are included as summary rows (no pagination needed for numbers).
    """
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    try:
        questions, total_sessions, answers_by_question = _fetch_stats_data(event_id)

        if not questions:
            return {"event_id": event_id, "total_sessions": 0, "page": page, "questions": []}

        results = []
        for q in questions:
            qid = q["question_id"]

            # If filtering to a specific question, skip others
            if question_id is not None and qid != question_id:
                continue

            q_answers = answers_by_question.get(qid, [])

            if q["question_type"] == "rating":
                # Ratings don't paginate — always return the summary
                nums  = [a["answer_number"] for a in q_answers if a["answer_number"] is not None]
                min_v = q.get("min_value") or 1
                max_v = q.get("max_value") or 5
                dist  = {i: 0 for i in range(int(min_v), int(max_v) + 1)}
                for n in nums:
                    k = int(n)
                    if k in dist:
                        dist[k] += 1
                results.append({
                    "question_id":   qid,
                    "question_text": q["question_text"],
                    "type":          "rating",
                    "total_answers": len(nums),
                    "average":       round(sum(nums) / len(nums), 2) if nums else 0,
                    "distribution":  dist,
                    "paginated":     False,
                })

            elif q["question_type"] == "text":
                sorted_answers = sorted(
                    q_answers,
                    key=lambda a: a.get("answered_at") or "",
                    reverse=True
                )
                texts       = [a["answer_text"] for a in sorted_answers if a["answer_text"]]
                total       = len(texts)
                total_pages = max(1, -(-total // page_size))  # ceiling division
                start       = (page - 1) * page_size
                end         = start + page_size

                results.append({
                    "question_id":   qid,
                    "question_text": q["question_text"],
                    "type":          "text",
                    "total_answers": total,
                    "responses":     texts[start:end],
                    "paginated":     True,
                    "pagination": {
                        "page":        page,
                        "page_size":   page_size,
                        "total_pages": total_pages,
                        "has_next":    page < total_pages,
                        "has_prev":    page > 1,
                    },
                })

        return {
            "event_id":       event_id,
            "total_sessions": total_sessions,
            "page":           page,
            "questions":      results,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving paginated stats: {str(e)}")