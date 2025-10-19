import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
export const supabase = createClient(supabaseUrl, supabaseKey);

export async function adminLogin(email: string, password: string) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw new Error(error.message);
  return data;
}

export async function adminRegister({ email, password, name, adminKey }: {
  email: string;
  password: string;
  name: string;
  adminKey: string;
}) {
  // Backend expects x-api-key: Bearer <adminKey>
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/users/register`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': `Bearer ${adminKey}`,
    },
    body: JSON.stringify({ email, password, name })
  });
  if (!res.ok) {
    const error = await res.json().catch(() => null);
    throw new Error(error?.detail || error?.message || 'Registration failed');
  }
  return await res.json();
}
