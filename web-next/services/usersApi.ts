import { supabase } from "./adminAuth";

async function getAuthToken() {
  const { data: { session }, error } = await supabase.auth.getSession();
  if (error) throw new Error(`Auth error: ${error.message}`);
  const token = session?.access_token;
  if (!token) throw new Error("Not authenticated - no token available");
  return token;
}

export async function getAllUsers() {
  const token = await getAuthToken();
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/users/list`, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${token}`,
    },
  });
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to fetch users");
  }
  return await res.json();
}

export async function deleteUser(user_id: string) {
  const token = await getAuthToken();
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/users/delete/${user_id}`, {
    method: "DELETE",
    headers: {
      "Authorization": `Bearer ${token}`,
    },
  });
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || "Failed to delete user");
  }
  return await res.json();
}
