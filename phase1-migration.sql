-- Phase 1 Migration: User Authentication & Admin Capabilities
-- Run this in Supabase SQL Editor to add user authentication and admin features

-- Step 1: Extend users table with admin spoofing capabilities
ALTER TABLE users ADD COLUMN IF NOT EXISTS can_spoof_users BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS spoofed_user_id UUID REFERENCES auth.users(id);

-- Step 2: Create user_profiles table for extended user information
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  phone VARCHAR(20),
  date_of_birth DATE,
  emergency_contact_name VARCHAR(100),
  emergency_contact_phone VARCHAR(20),
  address_street VARCHAR(255),
  address_city VARCHAR(100),
  address_state VARCHAR(50),
  address_zip VARCHAR(20),
  competition_experience TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 3: Create admin_logs table for audit trail
CREATE TABLE IF NOT EXISTS admin_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_user_id UUID REFERENCES auth.users(id),
  action VARCHAR(100) NOT NULL,
  target_user_id UUID REFERENCES auth.users(id),
  details JSONB,
  ip_address INET,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 4: Create user_sessions table for spoofing support
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_token VARCHAR(255) UNIQUE NOT NULL,
  is_spoofed_session BOOLEAN DEFAULT FALSE,
  admin_user_id UUID REFERENCES auth.users(id), -- Admin who initiated spoofing
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 5: Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_id ON user_profiles(id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin_user_id ON admin_logs(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_target_user_id ON admin_logs(target_user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions(session_token);

-- Step 6: Enable RLS on new tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- Step 7: Create RLS policies for user_profiles
CREATE POLICY "Users can view their own profile" ON user_profiles FOR SELECT USING (
  auth.uid() = id
);

CREATE POLICY "Users can update their own profile" ON user_profiles FOR UPDATE USING (
  auth.uid() = id
);

CREATE POLICY "Users can insert their own profile" ON user_profiles FOR INSERT WITH CHECK (
  auth.uid() = id
);

CREATE POLICY "Admins can view all profiles" ON user_profiles FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
);

CREATE POLICY "Admins can update all profiles" ON user_profiles FOR UPDATE USING (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
);

-- Step 8: Create RLS policies for admin_logs
CREATE POLICY "Admins can view admin logs" ON admin_logs FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
);

CREATE POLICY "Admins can insert admin logs" ON admin_logs FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
);

-- Step 9: Create RLS policies for user_sessions
CREATE POLICY "Users can view their own sessions" ON user_sessions FOR SELECT USING (
  auth.uid() = user_id
);

CREATE POLICY "Users can manage their own sessions" ON user_sessions FOR ALL USING (
  auth.uid() = user_id
);

CREATE POLICY "Admins can view all sessions" ON user_sessions FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
);

-- Step 10: Create function for admin spoofing
CREATE OR REPLACE FUNCTION admin_spoof_user(target_user_uuid UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_check BOOLEAN;
  session_token VARCHAR(255);
  result JSONB;
BEGIN
  -- Check if current user is admin
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role = 'admin'
  ) INTO admin_check;

  IF NOT admin_check THEN
    RAISE EXCEPTION 'Access denied. Admin privileges required.';
  END IF;

  -- Generate session token
  session_token := encode(gen_random_bytes(32), 'hex');

  -- Create spoofed session
  INSERT INTO user_sessions (user_id, session_token, is_spoofed_session, admin_user_id, expires_at)
  VALUES (target_user_uuid, session_token, TRUE, auth.uid(), NOW() + INTERVAL '8 hours');

  -- Log the spoofing action
  INSERT INTO admin_logs (admin_user_id, action, target_user_id, details)
  VALUES (auth.uid(), 'spoof_user', target_user_uuid, jsonb_build_object('session_token', session_token));

  -- Return session info
  SELECT jsonb_build_object(
    'session_token', session_token,
    'target_user_id', target_user_uuid,
    'expires_at', (NOW() + INTERVAL '8 hours')::TEXT
  ) INTO result;

  RETURN result;
END;
$$;

-- Step 11: Create function to end spoofing session
CREATE OR REPLACE FUNCTION admin_end_spoof()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_check BOOLEAN;
BEGIN
  -- Check if current user is admin
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role = 'admin'
  ) INTO admin_check;

  IF NOT admin_check THEN
    RAISE EXCEPTION 'Access denied. Admin privileges required.';
  END IF;

  -- End all spoofed sessions for this admin
  UPDATE user_sessions
  SET expires_at = NOW()
  WHERE admin_user_id = auth.uid()
  AND is_spoofed_session = TRUE
  AND expires_at > NOW();

  -- Log the action
  INSERT INTO admin_logs (admin_user_id, action, details)
  VALUES (auth.uid(), 'end_spoof', jsonb_build_object('ended_all_sessions', true));

  RETURN TRUE;
END;
$$;

-- Step 12: Update existing users table RLS to support spoofing
-- (This allows admins to effectively act as other users)
DROP POLICY IF EXISTS "Admins can spoof as users" ON users;
CREATE POLICY "Admins can spoof as users" ON users FOR SELECT USING (
  EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin')
  OR auth.uid() = users.id
);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Migration completed successfully!
-- Next steps:
-- 1. Run this migration in Supabase SQL Editor
-- 2. Set up Supabase Auth configuration in your application
-- 3. Create admin user interface components
-- 4. Implement user profile management components