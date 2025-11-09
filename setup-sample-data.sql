-- Sample data setup for Dancing With The King event
-- Run this after the main schema to create a complete event

-- First, ensure we have the organization
DO $$
DECLARE
    org_id UUID;
    event_id UUID;
BEGIN
    -- Insert or get organization
    INSERT INTO organizations (name, type)
    VALUES ('Dancing With The King', 'Ballroom')
    ON CONFLICT DO NOTHING;

    SELECT id INTO org_id FROM organizations WHERE name = 'Dancing With The King' LIMIT 1;

    -- Insert the event (with registration deadline for rest of 2025)
    INSERT INTO events (organization_id, name, description, logo_url, start_date, end_date, registration_deadline)
    VALUES (
      org_id,
      'Dancing With The King 2025',
      'Sunday Ballroom Competition featuring Smooth and Rhythm categories',
      'https://dancingwiththeking.com/wp-content/uploads/2024/05/DWTK-logo-blue-600x420.png',
      '2025-12-01',
      '2025-12-01',
      '2025-12-31 23:59:59+00'  -- Extended to end of 2025 for development
    )
    RETURNING id INTO event_id;
END $$;

-- Insert age divisions (let Supabase generate UUIDs)
INSERT INTO age_divisions (name, min_age, max_age, display_order) VALUES
('Y1 12 & under', NULL, 12, 1),
('Y2 13-19', 13, 19, 2),
('A1 20-29', 20, 29, 3),
('A2 30-39', 30, 39, 4),
('B1 40-49', 40, 49, 5),
('B2 50-59', 50, 59, 6),
('C1 60-69', 60, 69, 7),
('C2 70 & up', 70, NULL, 8)
ON CONFLICT DO NOTHING;

-- Insert skill levels (let Supabase generate UUIDs)
INSERT INTO skill_levels (name, display_order) VALUES
('Newcomer', 1),
('Beginning Bronze', 2),
('Intermediate Bronze', 3),
('Full Bronze', 4),
('Beginning Silver', 5),
('Intermediate Silver', 6),
('Full Silver', 7),
('Gold', 8)
ON CONFLICT DO NOTHING;

-- Insert dance categories (let Supabase generate UUIDs)
INSERT INTO dance_categories (name, type, dances) VALUES
('Smooth', 'Smooth', ARRAY['Waltz', 'Tango', 'Foxtrot', 'V. Waltz']),
('Rhythm', 'Rhythm', ARRAY['Cha Cha', 'Rumba', 'Swing', 'Bolero', 'Mambo']),
('Club', 'Club', ARRAY['Nightclub 2-Step'])
ON CONFLICT DO NOTHING;

-- Insert event configuration using actual UUIDs from the database (only if it doesn't exist)
DO $$
DECLARE
    event_id UUID;
    age_divisions_json JSONB;
    skill_levels_json JSONB;
    dance_categories_json JSONB;
    config_exists BOOLEAN;
BEGIN
    -- Get the event ID
    SELECT id INTO event_id FROM events WHERE name = 'Dancing With The King 2025' LIMIT 1;

    -- Check if configuration already exists
    SELECT EXISTS(SELECT 1 FROM event_configurations WHERE event_configurations.event_id = setup.event_id) INTO config_exists
    FROM (SELECT event_id) AS setup;

    IF NOT config_exists THEN
        -- Build age divisions JSON with actual UUIDs
        SELECT jsonb_agg(
            jsonb_build_object(
                'id', id::text,
                'name', name,
                'min_age', min_age,
                'max_age', max_age,
                'display_order', display_order
            ) ORDER BY display_order
        ) INTO age_divisions_json
        FROM age_divisions;

        -- Build skill levels JSON with actual UUIDs
        SELECT jsonb_agg(
            jsonb_build_object(
                'id', id::text,
                'name', name,
                'display_order', display_order
            ) ORDER BY display_order
        ) INTO skill_levels_json
        FROM skill_levels;

        -- Build dance categories JSON with actual UUIDs
        SELECT jsonb_agg(
            jsonb_build_object(
                'id', id::text,
                'name', name,
                'type', type,
                'dances', dances
            )
        ) INTO dance_categories_json
        FROM dance_categories;

        -- Insert event configuration
        INSERT INTO event_configurations (event_id, age_divisions, skill_levels, dance_categories, max_adjacent_levels, max_age_levels)
        VALUES (event_id, age_divisions_json, skill_levels_json, dance_categories_json, 2, 2);
    END IF;
END $$;