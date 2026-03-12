import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'http://localhost:8000';
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImF1ZCI6ImF1dGhlbnRpY2F0ZWQiLCJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc3Mjg4NjA0MiwiZXhwIjoxODA0NDIyMDQyfQ.Y7tNBY9CwS0f2rOwuSlTWd-fm0Jx9lkAx8I0BZkBGck';

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY environment variables');
}

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Listen for new sponsors - ONLY via DB CDC (single source of truth, no duplicates)
export const subscribeToSponsors = (callback) => {
    const dbChannel = supabase
        .channel('public:sponsors_cdc')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'sponsors' }, (payload) => {
            callback(payload);
        })
        .subscribe();

    return () => {
        dbChannel.unsubscribe();
    };
};
