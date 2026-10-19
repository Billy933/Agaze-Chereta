import { createClient } from '@supabase/supabase-js';
export function database() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error('Supabase configuration is missing. Add the public variables to .env.local.');
  return createClient(url, key);
}
