import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.REACT_APP_SUPABASE_URL || '';
const supabaseAnonKey = process.env.REACT_APP_SUPABASE_ANON_KEY || '';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Auth helper functions
export const auth = {
  signUp: async (email: string, password: string) => {
    return await supabase.auth.signUp({ email, password });
  },

  signIn: async (email: string, password: string) => {
    return await supabase.auth.signInWithPassword({ email, password });
  },

  signOut: async () => {
    return await supabase.auth.signOut();
  },

  getUser: async () => {
    return await supabase.auth.getUser();
  },

  getSession: async () => {
    return await supabase.auth.getSession();
  },

  onAuthStateChange: (callback: (event: string, session: any) => void) => {
    return supabase.auth.onAuthStateChange(callback);
  }
};

// Database helper functions
export const db = {
  // User profiles
  getUserProfile: async (userId: string) => {
    return await supabase
      .from('user_profiles')
      .select('*')
      .eq('id', userId)
      .single();
  },

  updateUserProfile: async (userId: string, profile: any) => {
    return await supabase
      .from('user_profiles')
      .upsert({ id: userId, ...profile, updated_at: new Date().toISOString() });
  },

  // Events
  getEvents: async () => {
    return await supabase
      .from('events')
      .select(`
        *,
        organizations (
          name,
          type
        )
      `)
      .gte('registration_deadline', new Date().toISOString())
      .order('start_date', { ascending: true });
  },

  // Event configurations
  getEventConfig: async (eventId: string) => {
    return await supabase
      .from('event_configurations')
      .select('*')
      .eq('event_id', eventId)
      .single();
  },

  // Tickets
  getTicketTypes: async (eventId: string) => {
    return await supabase
      .from('ticket_types')
      .select('*')
      .eq('event_id', eventId)
      .eq('is_active', true)
      .order('display_order', { ascending: true });
  },

  getUserTickets: async (userId: string) => {
    return await supabase
      .from('user_tickets')
      .select(`
        *,
        ticket_types (*)
      `)
      .eq('user_id', userId)
      .order('purchase_date', { ascending: false });
  },

  // Admin functions
  adminSpoofUser: async (targetUserId: string) => {
    return await supabase.rpc('admin_spoof_user', { target_user_uuid: targetUserId });
  },

  adminEndSpoof: async () => {
    return await supabase.rpc('admin_end_spoof');
  }
};