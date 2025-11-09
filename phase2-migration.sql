-- Phase 2 Migration: Ticket Management System
-- Run this in Supabase SQL Editor to add ticket purchasing and management

-- Step 1: Create ticket_types table (defines available ticket types per event)
CREATE TABLE IF NOT EXISTS ticket_types (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  max_quantity INTEGER, -- NULL means unlimited
  allows_dance_entries BOOLEAN DEFAULT FALSE,
  allows_spectator BOOLEAN DEFAULT FALSE,
  allows_workshop BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(event_id, name)
);

-- Step 2: Create user_tickets table (purchased tickets)
CREATE TABLE IF NOT EXISTS user_tickets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  ticket_type_id UUID REFERENCES ticket_types(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1,
  purchase_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
  payment_id VARCHAR(255), -- External payment processor ID
  total_amount DECIMAL(10,2) NOT NULL,
  used_count INTEGER DEFAULT 0,
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 3: Create ticket_usage table (tracks how tickets are used)
CREATE TABLE IF NOT EXISTS ticket_usage (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_ticket_id UUID REFERENCES user_tickets(id) ON DELETE CASCADE,
  registration_id UUID REFERENCES registrations(id) ON DELETE CASCADE,
  usage_type VARCHAR(50) NOT NULL CHECK (usage_type IN ('dance_entry', 'spectator', 'workshop')),
  used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_ticket_id, registration_id, usage_type)
);

-- Step 4: Add ticket configuration to events table
ALTER TABLE events ADD COLUMN IF NOT EXISTS ticket_system_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE events ADD COLUMN IF NOT EXISTS ticket_sale_start TIMESTAMP WITH TIME ZONE;
ALTER TABLE events ADD COLUMN IF NOT EXISTS ticket_sale_end TIMESTAMP WITH TIME ZONE;

-- Step 5: Create ticket validation function
CREATE OR REPLACE FUNCTION validate_ticket_for_registration(
  p_user_id UUID,
  p_event_id UUID,
  p_registration_type VARCHAR(50)
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  has_valid_ticket BOOLEAN := FALSE;
  ticket_record RECORD;
BEGIN
  -- Check if event requires tickets
  IF NOT EXISTS (
    SELECT 1 FROM events
    WHERE id = p_event_id
    AND ticket_system_enabled = TRUE
  ) THEN
    RETURN TRUE; -- No ticket required
  END IF;

  -- Find valid tickets for this user and event
  SELECT ut.*, tt.allows_dance_entries, tt.allows_spectator, tt.allows_workshop
  INTO ticket_record
  FROM user_tickets ut
  JOIN ticket_types tt ON ut.ticket_type_id = tt.id
  WHERE ut.user_id = p_user_id
  AND tt.event_id = p_event_id
  AND ut.payment_status = 'completed'
  AND (ut.expires_at IS NULL OR ut.expires_at > NOW())
  AND ut.used_count < ut.quantity
  ORDER BY ut.purchase_date DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Check if ticket allows this type of registration
  CASE p_registration_type
    WHEN 'dance_entry' THEN
      has_valid_ticket := ticket_record.allows_dance_entries;
    WHEN 'spectator' THEN
      has_valid_ticket := ticket_record.allows_spectator;
    WHEN 'workshop' THEN
      has_valid_ticket := ticket_record.allows_workshop;
    ELSE
      has_valid_ticket := FALSE;
  END CASE;

  RETURN has_valid_ticket;
END;
$$;

-- Step 6: Create function to use a ticket
CREATE OR REPLACE FUNCTION use_ticket_for_registration(
  p_user_id UUID,
  p_event_id UUID,
  p_registration_id UUID,
  p_usage_type VARCHAR(50)
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  ticket_id UUID;
BEGIN
  -- Find an available ticket
  SELECT ut.id INTO ticket_id
  FROM user_tickets ut
  JOIN ticket_types tt ON ut.ticket_type_id = tt.id
  WHERE ut.user_id = p_user_id
  AND tt.event_id = p_event_id
  AND ut.payment_status = 'completed'
  AND (ut.expires_at IS NULL OR ut.expires_at > NOW())
  AND ut.used_count < ut.quantity
  ORDER BY ut.purchase_date ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No valid ticket found for user % and event %', p_user_id, p_event_id;
  END IF;

  -- Record the usage
  INSERT INTO ticket_usage (user_ticket_id, registration_id, usage_type)
  VALUES (ticket_id, p_registration_id, p_usage_type);

  -- Increment usage count
  UPDATE user_tickets
  SET used_count = used_count + 1
  WHERE id = ticket_id;

  RETURN TRUE;
END;
$$;

-- Step 7: Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_ticket_types_event_id ON ticket_types(event_id);
CREATE INDEX IF NOT EXISTS idx_user_tickets_user_id ON user_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_user_tickets_ticket_type_id ON user_tickets(ticket_type_id);
CREATE INDEX IF NOT EXISTS idx_ticket_usage_user_ticket_id ON ticket_usage(user_ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_usage_registration_id ON ticket_usage(registration_id);

-- Step 8: Enable RLS on new tables
ALTER TABLE ticket_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_usage ENABLE ROW LEVEL SECURITY;

-- Step 9: Create RLS policies for ticket_types
CREATE POLICY "Everyone can view active ticket types for upcoming events" ON ticket_types FOR SELECT USING (
  is_active = TRUE AND EXISTS (
    SELECT 1 FROM events
    WHERE events.id = ticket_types.event_id
    AND events.registration_deadline >= NOW()
  )
);

CREATE POLICY "Organizers can manage ticket types for their events" ON ticket_types FOR ALL USING (
  EXISTS (
    SELECT 1 FROM events e
    JOIN users u ON u.organization_id = e.organization_id
    WHERE e.id = ticket_types.event_id
    AND u.id = auth.uid()
    AND u.role IN ('admin', 'organizer')
  )
);

-- Step 10: Create RLS policies for user_tickets
CREATE POLICY "Users can view their own tickets" ON user_tickets FOR SELECT USING (
  auth.uid() = user_id
);

CREATE POLICY "Users can purchase tickets" ON user_tickets FOR INSERT WITH CHECK (
  auth.uid() = user_id
);

CREATE POLICY "Users can update their own tickets" ON user_tickets FOR UPDATE USING (
  auth.uid() = user_id
);

CREATE POLICY "Admins can view all tickets" ON user_tickets FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
);

-- Step 11: Create RLS policies for ticket_usage
CREATE POLICY "Users can view their own ticket usage" ON ticket_usage FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM user_tickets ut
    WHERE ut.id = ticket_usage.user_ticket_id
    AND ut.user_id = auth.uid()
  )
);

CREATE POLICY "System can insert ticket usage" ON ticket_usage FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_tickets ut
    WHERE ut.id = ticket_usage.user_ticket_id
    AND ut.user_id = auth.uid()
  )
);

-- Step 12: Sample ticket data for Dancing With The King
-- (This will be inserted after the event exists)
DO $$
DECLARE
  dwt_event_id UUID;
BEGIN
  SELECT id INTO dwt_event_id FROM events WHERE name = 'Dancing With The King 2025' LIMIT 1;

  IF dwt_event_id IS NOT NULL THEN
    -- Enable ticket system for the event
    UPDATE events SET ticket_system_enabled = TRUE WHERE id = dwt_event_id;

    -- Insert ticket types
    INSERT INTO ticket_types (event_id, name, description, price, allows_dance_entries, allows_spectator, allows_workshop, display_order) VALUES
    (dwt_event_id, 'Full Weekend Dancer Pass', 'Access to all dance competitions, workshops, and spectator events', 150.00, TRUE, TRUE, TRUE, 1),
    (dwt_event_id, 'Friday Dance Ticket', 'Access to Friday dance competition only', 75.00, TRUE, FALSE, FALSE, 2),
    (dwt_event_id, 'Saturday Workshop Ticket', 'Access to Saturday workshops only', 50.00, FALSE, FALSE, TRUE, 3),
    (dwt_event_id, 'Sunday Spectator Ticket', 'Access to Sunday spectator events only', 25.00, FALSE, TRUE, FALSE, 4)
    ON CONFLICT (event_id, name) DO NOTHING;
  END IF;
END $$;

-- Migration completed successfully!
-- Next steps:
-- 1. Run this migration in Supabase SQL Editor
-- 2. Set up payment processing integration (Stripe/PayPal)
-- 3. Create ticket purchasing UI components
-- 4. Implement ticket validation in registration flow