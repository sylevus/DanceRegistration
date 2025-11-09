-- Dance Registration System Database Schema for Supabase
-- Best practices applied: Primary keys, proper data types, relationships

-- Organizations table (Ballroom, UCWDC, ACDA, etc.)
CREATE TABLE organizations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  type VARCHAR(50) NOT NULL CHECK (type IN ('Ballroom', 'UCWDC', 'ACDA')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Events table
CREATE TABLE events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  logo_url VARCHAR(500),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  registration_deadline TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Age divisions
CREATE TABLE age_divisions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  min_age INTEGER,
  max_age INTEGER,
  display_order INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Skill levels
CREATE TABLE skill_levels (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  display_order INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Dance categories (Smooth, Rhythm, Club)
CREATE TABLE dance_categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(50) NOT NULL CHECK (type IN ('Smooth', 'Rhythm', 'Club')),
  dances TEXT[] NOT NULL, -- Array of dance names like ['Waltz', 'Tango', 'Foxtrot']
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Event configurations (links events to their specific divisions, levels, and categories)
CREATE TABLE event_configurations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE UNIQUE,
  age_divisions JSONB NOT NULL, -- Array of age division objects
  skill_levels JSONB NOT NULL, -- Array of skill level objects
  dance_categories JSONB NOT NULL, -- Array of dance category objects
  max_adjacent_levels INTEGER DEFAULT 2,
  max_age_levels INTEGER DEFAULT 2,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Dancers table
CREATE TABLE dancers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  phone VARCHAR(20),
  date_of_birth DATE,
  is_professional BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Partnerships table
CREATE TABLE partnerships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  leader_id UUID REFERENCES dancers(id) ON DELETE CASCADE,
  follower_id UUID REFERENCES dancers(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(leader_id, follower_id, event_id) -- Prevent duplicate partnerships per event
);

-- Registrations table
CREATE TABLE registrations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  partnership_id UUID REFERENCES partnerships(id) ON DELETE CASCADE,
  age_division_id VARCHAR(255) NOT NULL, -- String ID from event configuration
  skill_level_id VARCHAR(255) NOT NULL, -- String ID from event configuration
  selected_dances TEXT[] NOT NULL, -- Array of dance identifiers
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'paid', 'cancelled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Heats table (for future heating system)
CREATE TABLE heats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  age_division_id VARCHAR(255) NOT NULL, -- String ID from event configuration
  skill_level_id VARCHAR(255) NOT NULL, -- String ID from event configuration
  dance_category_id VARCHAR(255) NOT NULL, -- String ID from event configuration
  dance_name VARCHAR(100) NOT NULL,
  heat_number INTEGER NOT NULL,
  round INTEGER DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(event_id, age_division_id, skill_level_id, dance_category_id, dance_name, heat_number, round)
);

-- Heat entries (links partnerships to heats)
CREATE TABLE heat_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  heat_id UUID REFERENCES heats(id) ON DELETE CASCADE,
  partnership_id UUID REFERENCES partnerships(id) ON DELETE CASCADE,
  position INTEGER, -- Position in heat (optional, for results)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(heat_id, partnership_id)
);

-- Payments table
CREATE TABLE payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  registration_id UUID REFERENCES registrations(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('card', 'check', 'cash')),
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  transaction_id VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Users table for authentication (extends Supabase auth.users)
CREATE TABLE users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'organizer')),
  organization_id UUID REFERENCES organizations(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_events_organization_id ON events(organization_id);
CREATE INDEX idx_events_registration_deadline ON events(registration_deadline);
CREATE INDEX idx_event_configurations_event_id ON event_configurations(event_id);
CREATE INDEX idx_partnerships_event_id ON partnerships(event_id);
CREATE INDEX idx_partnerships_leader_id ON partnerships(leader_id);
CREATE INDEX idx_partnerships_follower_id ON partnerships(follower_id);
CREATE INDEX idx_registrations_partnership_id ON registrations(partnership_id);
CREATE INDEX idx_heats_event_id ON heats(event_id);
CREATE INDEX idx_heat_entries_heat_id ON heat_entries(heat_id);
CREATE INDEX idx_heat_entries_partnership_id ON heat_entries(partnership_id);
CREATE INDEX idx_payments_registration_id ON payments(registration_id);
CREATE INDEX idx_users_organization_id ON users(organization_id);

-- Row Level Security (RLS) Policies

-- Enable RLS
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE dancers ENABLE ROW LEVEL SECURITY;
ALTER TABLE partnerships ENABLE ROW LEVEL SECURITY;
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE heats ENABLE ROW LEVEL SECURITY;
ALTER TABLE heat_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Organizations: Public read, admin write
CREATE POLICY "Organizations are viewable by everyone" ON organizations FOR SELECT USING (true);
CREATE POLICY "Organizations are manageable by admins" ON organizations FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
);

-- Events: Public read for upcoming events, organizers can manage their events
CREATE POLICY "Upcoming events are viewable by everyone" ON events FOR SELECT USING (
  registration_deadline >= NOW()
);
CREATE POLICY "Events are manageable by organizers" ON events FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND (users.role = 'admin' OR users.organization_id = events.organization_id))
);

-- Similar policies for other tables (simplified for brevity)
-- In production, you'd want more granular policies based on user roles and relationships

-- Sample data is now in setup-sample-data.sql for better organization