import { API_BASE_URL } from "./api";
import { supabase } from "@/services/adminAuth";

/* ── Types ───────────────────────────────────────────────────────── */

export interface AdminRatingQuestion {
  question_id: number;
  question_text: string;
  type: "rating";
  total_answers: number;
  average: number;
  distribution: Record<string, number>;
}

export interface AdminTextQuestion {
  question_id: number;
  question_text: string;
  type: "text";
  total_answers: number;
  recent_responses: string[];
  has_more: boolean;
}

export type AdminQuestion = AdminRatingQuestion | AdminTextQuestion;

export interface AdminFeedbackStats {
  event_id: number;
  total_sessions: number;
  questions: AdminQuestion[];
}

export interface PaginatedPagination {
  page: number;
  page_size: number;
  total_pages: number;
  has_next: boolean;
  has_prev: boolean;
}

export interface PaginatedRatingQuestion {
  question_id: number;
  question_text: string;
  type: "rating";
  paginated: false;
  total_answers: number;
  average: number;
  distribution: Record<string, number>;
}

export interface PaginatedTextQuestion {
  question_id: number;
  question_text: string;
  type: "text";
  paginated: true;
  total_answers: number;
  responses: string[];
  pagination: PaginatedPagination;
}

export type PaginatedQuestion = PaginatedRatingQuestion | PaginatedTextQuestion;

export interface AdminFeedbackStatsPage {
  event_id: number;
  total_sessions: number;
  page: number;
  questions: PaginatedQuestion[];
}

// --- onboarding stats for event 1 ------------------------------------------------
export interface OnboardingStats {
  total_registered: number;
  currently_inside: number;
  feedback_submissions: number;
  date_wise: {
    registrations: Record<string, number>;
    entries: Record<string, number>;
  };
}

/** POST /admin/onboarding */
export async function getAdminOnboardingStats(): Promise<OnboardingStats> {
  const headers = await authHeaders();
  const res = await fetch(`${API_BASE_URL}/admin/onboarding`, { method: "POST", headers });
  if (!res.ok) {
    const err = await res.json().catch(() => null);
    throw new Error(err?.detail ?? `Onboarding stats fetch failed (${res.status})`);
  }
  return res.json();
}

/* ── Auth helper ─────────────────────────────────────────────────── */

async function authHeaders(): Promise<HeadersInit> {
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session?.access_token)
    throw new Error("Not authenticated. Please log in again.");
  return { Authorization: `Bearer ${session.access_token}` };
}

const FB = `${API_BASE_URL}/feedback`;

/* ── API functions ───────────────────────────────────────────────── */

/** GET /feedback/event/{id}/stats?recent={n} */
export async function getAdminFeedbackStats(
  eventId: number,
  recent = 5
): Promise<AdminFeedbackStats> {
  const headers = await authHeaders();
  const res = await fetch(`${FB}/event/${eventId}/stats?recent=${recent}`, {
    headers,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => null);
    throw new Error(err?.detail ?? `Stats fetch failed (${res.status})`);
  }
  return res.json();
}

/** GET /feedback/event/{id}/stats/page/{page}?page_size={n}&question_id={q} */
export async function getAdminFeedbackStatsPage(
  eventId: number,
  page: number,
  pageSize = 20,
  questionId?: number
): Promise<AdminFeedbackStatsPage> {
  const headers = await authHeaders();
  const params = new URLSearchParams({ page_size: String(pageSize) });
  if (questionId !== undefined) params.set("question_id", String(questionId));
  const res = await fetch(
    `${FB}/event/${eventId}/stats/page/${page}?${params}`,
    { headers }
  );
  if (!res.ok) {
    const err = await res.json().catch(() => null);
    throw new Error(err?.detail ?? `Stats page fetch failed (${res.status})`);
  }
  return res.json();
}

/** GET /feedback/event/{id}/export — triggers CSV file download */
export async function exportFeedbackCSV(eventId: number): Promise<void> {
  const headers = await authHeaders();
  const res = await fetch(`${FB}/event/${eventId}/export`, { headers });
  if (!res.ok) {
    const err = await res.json().catch(() => null);
    throw new Error(err?.detail ?? `Export failed (${res.status})`);
  }
  const blob = await res.blob();
  const cd = res.headers.get("content-disposition") ?? "";
  const filename =
    cd.match(/filename=["']?([^"';\n]+)/)?.[1] ??
    `feedback_event_${eventId}.csv`;
  const url = URL.createObjectURL(blob);
  const a = Object.assign(document.createElement("a"), {
    href: url,
    download: filename,
  });
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
