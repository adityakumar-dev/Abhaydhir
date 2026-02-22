import { supabase } from "./adminAuth";

async function getAuthToken() {
  const { data: { session }, error } = await supabase.auth.getSession();
  if (error) throw new Error(`Auth error: ${error.message}`);
  const token = session?.access_token;
  if (!token) throw new Error("Not authenticated - no token available");
  return token;
}

export async function getAllTourists(limit = 20, offset = 0) {
  const token = await getAuthToken();
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/tourists?limit=${limit}&offset=${offset}`, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${token}`,
    },
  });
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to fetch tourists");
  }
  return await res.json();
}

export async function getTouristsByEvent(event_id: number, limit = 20, offset = 0) {
  const token = await getAuthToken();
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/tourist/event/${event_id}?limit=${limit}&offset=${offset}`, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${token}`,
    },
  });
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to fetch tourists for event");
  }
  return await res.json();
}

export async function getTouristById(user_id: number) {
  const token = await getAuthToken();
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/tourist/${user_id}`, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${token}`,
    },
  });
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to fetch tourist");
  }
  return await res.json();
}

/* ── Public short code resolution (no auth) ── */

export interface ShortCodeResponse {
  success: boolean;
  short_code: string;
  user_id: number;
  card_urls: {
    preview: string;
    download: string;
  };
  token: string;
  created_at: string;
}

export async function resolveShortCode(shortCode: string): Promise<ShortCodeResponse> {
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/tourists/short/${shortCode}`);
  if (res.status === 404) throw new Error("Short code not found");
  if (res.status === 410) throw new Error("Token expired - short link is no longer valid");
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to resolve short code");
  }
  return await res.json();
}

/** Fetch visitor card image (or trigger download) */
export async function getVisitorCard(token: string, download = false): Promise<Blob> {
  const url = `${process.env.NEXT_PUBLIC_API_URL}/tourists/visitor-card/${token}${download ? "?download=true" : ""}`;
  const res = await fetch(url);
  if (res.status === 400) throw new Error("Invalid token format");
  if (res.status === 403) throw new Error("Token expired or invalid");
  if (res.status === 404) throw new Error("Card not found");
  if (!res.ok) {
    throw new Error("Failed to fetch visitor card");
  }
  return await res.blob();
}