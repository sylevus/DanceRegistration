export interface Organization {
  id: string;
  name: string;
  type: 'Ballroom' | 'UCWDC' | 'ACDA';
  created_at: string;
}

export interface Event {
  id: string;
  organization_id: string;
  name: string;
  description?: string;
  logo_url?: string;
  start_date: string;
  end_date: string;
  registration_deadline: string;
  created_at: string;
}

export interface AgeDivision {
  id: string;
  name: string;
  min_age?: number;
  max_age?: number;
  display_order: number;
}

export interface SkillLevel {
  id: string;
  name: string;
  display_order: number;
}

export interface DanceCategory {
  id: string;
  name: string;
  type: 'Smooth' | 'Rhythm' | 'Club';
  dances: string[]; // e.g., ['Waltz', 'Tango', 'Foxtrot']
}

export interface EventConfiguration {
  id: string;
  event_id: string;
  age_divisions: AgeDivision[];
  skill_levels: SkillLevel[];
  dance_categories: DanceCategory[];
  max_adjacent_levels: number;
  max_age_levels: number;
}

export interface Dancer {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone?: string;
  date_of_birth?: string;
  is_professional: boolean;
  created_at: string;
}

export interface Partnership {
  id: string;
  leader_id: string;
  follower_id: string;
  event_id: string;
  created_at: string;
}

export interface Registration {
  id: string;
  partnership_id: string;
  age_division_id: string;
  skill_level_id: string;
  selected_dances: string[]; // dance IDs
  status: 'pending' | 'confirmed' | 'paid';
  created_at: string;
}

export interface Heat {
  id: string;
  event_id: string;
  age_division_id: string;
  skill_level_id: string;
  dance_category_id: string;
  dance_name: string;
  heat_number: number;
  round: number;
  created_at: string;
}

export interface HeatEntry {
  id: string;
  heat_id: string;
  partnership_id: string;
  position?: number;
  created_at: string;
}

export interface Payment {
  id: string;
  registration_id: string;
  amount: number;
  payment_method: 'card' | 'check' | 'cash';
  status: 'pending' | 'completed' | 'failed';
  transaction_id?: string;
  created_at: string;
}

// Form state types
export interface PartnershipFormData {
  leader?: {
    first_name: string;
    last_name: string;
    email: string;
    phone?: string;
    date_of_birth?: string;
    is_professional: boolean;
  };
  follower?: {
    first_name: string;
    last_name: string;
    email: string;
    phone?: string;
    date_of_birth?: string;
    is_professional: boolean;
  };
}

export interface RegistrationFormData {
  selected_event_id: string;
  partnership: PartnershipFormData;
  selected_age_divisions: string[]; // up to 2 adjacent
  selected_skill_levels: string[]; // up to 2
  selected_dances: { [danceId: string]: boolean };
}