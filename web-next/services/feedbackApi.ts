import { API_BASE_URL } from "./api";

export interface FeedbackSubmission {
  event_id: number;
  rating: number;
  comment?: string;
  session_id?: string;
  fingerprint: string;
  metadata?: Record<string, unknown>;
}

export interface FeedbackSession {
  session_id: string;
  message: string;
}

export interface FeedbackStats {
  event_id: number;
  total_feedback: number;
  average_rating: number;
  rating_distribution: Record<number, number>;
}

export interface FeedbackResponse {
  success: boolean;
  message: string;
  feedback_id: string;
  session_id: string;
}

/* ─── Question-based feedback types ─── */

export interface FeedbackQuestion {
  question_id: number;
  question_text: string;
  question_type: "rating" | "text";
  is_required: boolean;
  display_order: number;
  min_value: number | null;
  max_value: number | null;
}

export interface EventQuestionsResponse {
  event_id: number;
  event_name: string;
  questions: FeedbackQuestion[];
}

export interface FeedbackAnswer {
  question_id: number;
  answer_number?: number;
  answer_text?: string;
}

export interface SubmitAnswersPayload {
  answers: FeedbackAnswer[];
  device_fingerprint?: string;
}

const FEEDBACK_BASE = `${API_BASE_URL}/feedback`;

/**
 * Create a new anonymous session for feedback submission
 */
export async function createFeedbackSession(): Promise<FeedbackSession> {
  const res = await fetch(`${FEEDBACK_BASE}/session`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });

  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to create feedback session");
  }

  return res.json();
}

/**
 * Submit anonymous feedback for an event
 */
export async function submitFeedback(
  data: FeedbackSubmission
): Promise<FeedbackResponse> {
  const res = await fetch(`${FEEDBACK_BASE}/anonymous/submit`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  });

  if (!res.ok) {
    const error = await res.json().catch(() => null);
    const status = res.status;

    if (status === 429) {
      throw new Error(
        error?.detail || "Too many submissions. Please try again later."
      );
    }
    if (status === 409) {
      throw new Error(
        error?.detail || "You have already submitted feedback for this event."
      );
    }
    if (status === 400) {
      throw new Error(error?.detail || "Invalid feedback data.");
    }
    if (status === 404) {
      throw new Error(error?.detail || "Event not found.");
    }

    throw new Error(error?.detail || "Failed to submit feedback");
  }

  return res.json();
}

/**
 * Fetch dynamic questions for an event
 */
export async function getEventQuestions(
  eventId: number
): Promise<EventQuestionsResponse> {
  const res = await fetch(`${FEEDBACK_BASE}/event/${eventId}/questions`, {
    method: "GET",
    headers: { "Content-Type": "application/json" },
  });

  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to fetch event questions");
  }

  return res.json();
}

/**
 * Submit question-based feedback answers for an event
 */
export async function submitEventAnswers(
  eventId: number,
  payload: SubmitAnswersPayload
): Promise<FeedbackResponse> {
  const res = await fetch(`${FEEDBACK_BASE}/event/${eventId}/submit`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const error = await res.json().catch(() => null);
    const status = res.status;

    if (status === 429) {
      throw new Error(
        error?.detail || "Too many submissions. Please try again later."
      );
    }
    if (status === 409) {
      throw new Error(
        error?.detail || "You have already submitted feedback for this event."
      );
    }
    if (status === 400) {
      throw new Error(error?.detail || "Invalid feedback data.");
    }
    if (status === 404) {
      throw new Error(error?.detail || "Event not found.");
    }

    throw new Error(error?.detail || "Failed to submit feedback");
  }

  return res.json();
}
export async function getEventFeedbackStats(
  eventId: number
): Promise<FeedbackStats> {
  const res = await fetch(`${FEEDBACK_BASE}/event/${eventId}/stats`, {
    method: "GET",
    headers: { "Content-Type": "application/json" },
  });

  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to fetch feedback stats");
  }

  return res.json();
}
