import { supabase } from "./adminAuth";

async function getAuthToken() {
  const { data: { session }, error } = await supabase.auth.getSession();
  if (error) throw new Error(`Auth error: ${error.message}`);
  const token = session?.access_token;
  if (!token) throw new Error("Not authenticated - no token available");
  return token;
}

export async function createEvent(event: {
  name: string;
  description?: string;
  start_date: string;
  end_date: string;
  location: string;
  max_capacity?: string;
  is_active: boolean;
}) {
  const token = await getAuthToken();
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/event/register`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`,
    },
    body: JSON.stringify({
      name: event.name,
      description: event.description || "",
      start_date: new Date(event.start_date).toISOString(),
      end_date: new Date(event.end_date).toISOString(),
      location: event.location,
      event_entries: ["main_gate"],
      max_capacity: event.max_capacity ? Number(event.max_capacity) : null,
      is_active: event.is_active,
      entry_rules: {},
      metadata: {}
    }),
  });
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || error?.message || "Event registration failed");
  }
  return await res.json();
}

export async function getAllEvents() {
  const token = await getAuthToken();
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/event/`, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${token}`,
    },
  });
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to fetch events");
  }
  return await res.json();
}

export async function updateEventStatus(event_id: number, is_active: boolean) {
  const token = await getAuthToken();
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/event/status?event_id=${event_id}&is_active=${is_active}`, {
    method: "PUT",
    headers: {
      "Authorization": `Bearer ${token}`,
    },
  });
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to update event status");
  }
  return await res.json();
}

export async function updateEventGuards(event_id: number, allowed_guards: string[]) {
  const token = await getAuthToken();
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/event/${event_id}/guards`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`,
    },
    body: JSON.stringify({ allowed_guards }),
  });
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to update guards");
  }
  return await res.json();
}
