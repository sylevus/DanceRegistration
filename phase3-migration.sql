-- Phase 3 Migration: Multi-Partnership Registration System
-- Run this in Supabase SQL Editor to add complex registration capabilities

-- Step 1: Create registration_groups table (groups multiple partnerships under one ticket)
CREATE TABLE IF NOT EXISTS registration_groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_ticket_id UUID REFERENCES user_tickets(id) ON DELETE SET NULL,
  name VARCHAR(100), -- Optional group name
  status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'confirmed', 'paid', 'cancelled')),
  total_amount DECIMAL(10,2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, event_id, name) -- Prevent duplicate group names per user per event
);

-- Step 2: Create registration_entries table (individual dance entries within a registration)
CREATE TABLE IF NOT EXISTS registration_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  registration_group_id UUID REFERENCES registration_groups(id) ON DELETE CASCADE,
  partnership_id UUID REFERENCES partnerships(id) ON DELETE CASCADE,
  age_division_id VARCHAR(255) NOT NULL,
  skill_level_id VARCHAR(255) NOT NULL,
  selected_dances TEXT[] NOT NULL,
  entry_fee DECIMAL(10,2) DEFAULT 0,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'paid', 'cancelled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 3: Modify partnerships table to support multiple partners per user per event
ALTER TABLE partnerships ADD COLUMN IF NOT EXISTS registration_group_id UUID REFERENCES registration_groups(id) ON DELETE SET NULL;
ALTER TABLE partnerships ADD COLUMN IF NOT EXISTS partnership_type VARCHAR(20) DEFAULT 'standard' CHECK (partnership_type IN ('standard', 'pro_am', 'two_amateurs'));

-- Step 4: Create partnership_members table for complex partnerships
CREATE TABLE IF NOT EXISTS partnership_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  partnership_id UUID REFERENCES partnerships(id) ON DELETE CASCADE,
  dancer_id UUID REFERENCES dancers(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL CHECK (role IN ('leader', 'follower', 'pro_leader', 'amateur_leader', 'amateur_follower')),
  is_professional BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(partnership_id, dancer_id)
);

-- Step 5: Create function to validate complex registration
CREATE OR REPLACE FUNCTION validate_registration_group(
  p_group_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  group_record RECORD;
  entry_count INTEGER;
  ticket_validation BOOLEAN;
  result JSONB;
  errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
  -- Get group details
  SELECT rg.*, e.ticket_system_enabled, e.id as event_id, ut.user_id as ticket_user_id
  INTO group_record
  FROM registration_groups rg
  JOIN events e ON rg.event_id = e.id
  LEFT JOIN user_tickets ut ON rg.user_ticket_id = ut.id
  WHERE rg.id = p_group_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'errors', ARRAY['Registration group not found']);
  END IF;

  -- Count entries
  SELECT COUNT(*) INTO entry_count FROM registration_entries WHERE registration_group_id = p_group_id;

  -- Validate ticket requirements if ticket system is enabled
  IF group_record.ticket_system_enabled THEN
    IF group_record.user_ticket_id IS NULL THEN
      errors := errors || 'Ticket required for this event';
    ELSE
      -- Check if ticket allows dance entries
      SELECT tt.allows_dance_entries INTO ticket_validation
      FROM user_tickets ut
      JOIN ticket_types tt ON ut.ticket_type_id = tt.id
      WHERE ut.id = group_record.user_ticket_id;

      IF NOT ticket_validation THEN
        errors := errors || 'Selected ticket does not allow dance entries';
      END IF;

      -- Check if ticket has sufficient uses remaining
      SELECT (ut.quantity - ut.used_count) >= entry_count INTO ticket_validation
      FROM user_tickets ut
      WHERE ut.id = group_record.user_ticket_id;

      IF NOT ticket_validation THEN
        errors := errors || 'Insufficient ticket uses remaining';
      END IF;
    END IF;
  END IF;

  -- Validate each entry has required fields
  IF entry_count = 0 THEN
    errors := errors || 'At least one dance entry required';
  END IF;

  -- Check for duplicate partnerships in same division/level
  IF EXISTS (
    SELECT 1
    FROM registration_entries re1
    JOIN registration_entries re2 ON re1.id != re2.id
    WHERE re1.registration_group_id = p_group_id
    AND re2.registration_group_id = p_group_id
    AND re1.partnership_id = re2.partnership_id
    AND re1.age_division_id = re2.age_division_id
    AND re1.skill_level_id = re2.skill_level_id
  ) THEN
    errors := errors || 'Duplicate partnership entries in same division/level';
  END IF;

  -- Return validation result
  IF array_length(errors, 1) > 0 THEN
    RETURN jsonb_build_object('valid', false, 'errors', errors);
  ELSE
    RETURN jsonb_build_object('valid', true, 'entry_count', entry_count);
  END IF;
END;
$$;

-- Step 6: Create function to submit registration group
CREATE OR REPLACE FUNCTION submit_registration_group(
  p_group_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  validation_result JSONB;
  group_record RECORD;
  entry_record RECORD;
BEGIN
  -- Validate the group
  SELECT validate_registration_group(p_group_id) INTO validation_result;

  IF NOT (validation_result->>'valid')::BOOLEAN THEN
    RETURN validation_result;
  END IF;

  -- Get group details
  SELECT * INTO group_record FROM registration_groups WHERE id = p_group_id;

  -- Update group status
  UPDATE registration_groups SET status = 'submitted', updated_at = NOW() WHERE id = p_group_id;

  -- Update all entries to submitted
  UPDATE registration_entries SET status = 'submitted', updated_at = NOW()
  WHERE registration_group_id = p_group_id;

  -- Use tickets for each entry
  FOR entry_record IN SELECT * FROM registration_entries WHERE registration_group_id = p_group_id LOOP
    -- Use ticket for each dance entry
    PERFORM use_ticket_for_registration(
      group_record.user_id,
      group_record.event_id,
      entry_record.id,
      'dance_entry'
    );
  END LOOP;

  RETURN jsonb_build_object('success', true, 'message', 'Registration submitted successfully');
END;
$$;

-- Step 7: Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_registration_groups_user_id ON registration_groups(user_id);
CREATE INDEX IF NOT EXISTS idx_registration_groups_event_id ON registration_groups(event_id);
CREATE INDEX IF NOT EXISTS idx_registration_groups_user_ticket_id ON registration_groups(user_ticket_id);
CREATE INDEX IF NOT EXISTS idx_registration_entries_registration_group_id ON registration_entries(registration_group_id);
CREATE INDEX IF NOT EXISTS idx_registration_entries_partnership_id ON registration_entries(partnership_id);
CREATE INDEX IF NOT EXISTS idx_partnership_members_partnership_id ON partnership_members(partnership_id);
CREATE INDEX IF NOT EXISTS idx_partnership_members_dancer_id ON partnership_members(dancer_id);

-- Step 8: Enable RLS on new tables
ALTER TABLE registration_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE registration_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE partnership_members ENABLE ROW LEVEL SECURITY;

-- Step 9: Create RLS policies for registration_groups
CREATE POLICY "Users can view their own registration groups" ON registration_groups FOR SELECT USING (
  auth.uid() = user_id
);

CREATE POLICY "Users can create their own registration groups" ON registration_groups FOR INSERT WITH CHECK (
  auth.uid() = user_id
);

CREATE POLICY "Users can update their own registration groups" ON registration_groups FOR UPDATE USING (
  auth.uid() = user_id
);

CREATE POLICY "Admins can view all registration groups" ON registration_groups FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
);

-- Step 10: Create RLS policies for registration_entries
CREATE POLICY "Users can view their own registration entries" ON registration_entries FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM registration_groups rg
    WHERE rg.id = registration_entries.registration_group_id
    AND rg.user_id = auth.uid()
  )
);

CREATE POLICY "Users can manage their own registration entries" ON registration_entries FOR ALL USING (
  EXISTS (
    SELECT 1 FROM registration_groups rg
    WHERE rg.id = registration_entries.registration_group_id
    AND rg.user_id = auth.uid()
  )
);

-- Step 11: Create RLS policies for partnership_members
CREATE POLICY "Users can view partnership members for their registrations" ON partnership_members FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM partnerships p
    JOIN registration_groups rg ON p.registration_group_id = rg.id
    WHERE p.id = partnership_members.partnership_id
    AND rg.user_id = auth.uid()
  )
);

CREATE POLICY "Users can manage partnership members for their registrations" ON partnership_members FOR ALL USING (
  EXISTS (
    SELECT 1 FROM partnerships p
    JOIN registration_groups rg ON p.registration_group_id = rg.id
    WHERE p.id = partnership_members.partnership_id
    AND rg.user_id = auth.uid()
  )
);

-- Step 12: Create trigger to update timestamps
CREATE TRIGGER update_registration_groups_updated_at
  BEFORE UPDATE ON registration_groups
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_registration_entries_updated_at
  BEFORE UPDATE ON registration_entries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Step 13: Migrate existing registrations to new structure
-- (This handles backward compatibility)
DO $$
DECLARE
  reg_record RECORD;
  group_id UUID;
BEGIN
  -- For each existing registration, create a registration group and entry
  FOR reg_record IN SELECT * FROM registrations LOOP
    -- Create registration group
    INSERT INTO registration_groups (user_id, event_id, status, created_at)
    SELECT
      d.email::UUID, -- This is a simplification - you'd need to map dancer emails to user IDs
      p.event_id,
      CASE WHEN reg_record.status = 'pending' THEN 'draft' ELSE reg_record.status END,
      reg_record.created_at
    FROM partnerships p
    JOIN dancers d ON p.leader_id = d.id
    WHERE p.id = reg_record.partnership_id
    RETURNING id INTO group_id;

    -- Create registration entry
    INSERT INTO registration_entries (
      registration_group_id,
      partnership_id,
      age_division_id,
      skill_level_id,
      selected_dances,
      status,
      created_at
    ) VALUES (
      group_id,
      reg_record.partnership_id,
      reg_record.age_division_id,
      reg_record.skill_level_id,
      reg_record.selected_dances,
      reg_record.status,
      reg_record.created_at
    );

    -- Link partnership to group
    UPDATE partnerships SET registration_group_id = group_id WHERE id = reg_record.partnership_id;
  END LOOP;
END $$;

-- Migration completed successfully!
-- Next steps:
-- 1. Run this migration in Supabase SQL Editor
-- 2. Update registration components to use new multi-partnership system
-- 3. Implement complex partnership creation UI
-- 4. Add registration group management features