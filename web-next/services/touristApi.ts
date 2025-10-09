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
