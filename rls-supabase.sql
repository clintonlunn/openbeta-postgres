-- OpenBeta RLS Policies for Supabase
-- Run this after schema-v2.sql to configure production-ready security
--
-- Security Model:
-- 1. Public data (areas, climbs, orgs) - readable by everyone (anon + authenticated)
-- 2. User data (ticks, media) - users can only access their own
-- 3. Editor role - can modify climbing data (areas, climbs)
-- 4. Admin role - can manage organizations and users

-- ============================================================================
-- HELPER FUNCTION: Get current user ID from Supabase JWT
-- ============================================================================
-- Supabase provides auth.uid() but we create a wrapper for consistency
CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID AS $$
BEGIN
    RETURN auth.uid();
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- HELPER FUNCTION: Check if current user is an editor
-- ============================================================================
CREATE OR REPLACE FUNCTION is_editor() RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid()
        AND is_editor = true
        AND deleted_at IS NULL
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- HELPER FUNCTION: Check if current user is an admin
-- ============================================================================
CREATE OR REPLACE FUNCTION is_admin() RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid()
        AND is_admin = true
        AND deleted_at IS NULL
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- DROP EXISTING POLICIES (if any)
-- ============================================================================
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol.policyname, pol.tablename);
    END LOOP;
END $$;

-- ============================================================================
-- ENABLE RLS ON ALL TABLES
-- ============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE climbs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pitches ENABLE ROW LEVEL SECURITY;
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE entity_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticks ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE history ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- USERS TABLE
-- ============================================================================
-- Anyone can view non-deleted user profiles
CREATE POLICY "users_select" ON users
    FOR SELECT USING (deleted_at IS NULL);

-- Users can update their own profile
CREATE POLICY "users_update_own" ON users
    FOR UPDATE USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Users can insert their own profile (on signup)
CREATE POLICY "users_insert_own" ON users
    FOR INSERT WITH CHECK (id = auth.uid());

-- ============================================================================
-- AREAS TABLE (public climbing data)
-- ============================================================================
-- Anyone can read non-deleted areas
CREATE POLICY "areas_select" ON areas
    FOR SELECT USING (deleted_at IS NULL);

-- Editors can insert new areas
CREATE POLICY "areas_insert" ON areas
    FOR INSERT WITH CHECK (is_editor());

-- Editors can update areas
CREATE POLICY "areas_update" ON areas
    FOR UPDATE USING (is_editor() AND deleted_at IS NULL)
    WITH CHECK (is_editor());

-- Editors can soft-delete areas (set deleted_at)
CREATE POLICY "areas_delete" ON areas
    FOR DELETE USING (is_editor());

-- ============================================================================
-- CLIMBS TABLE (public climbing data)
-- ============================================================================
-- Anyone can read non-deleted climbs
CREATE POLICY "climbs_select" ON climbs
    FOR SELECT USING (deleted_at IS NULL);

-- Editors can insert new climbs
CREATE POLICY "climbs_insert" ON climbs
    FOR INSERT WITH CHECK (is_editor());

-- Editors can update climbs
CREATE POLICY "climbs_update" ON climbs
    FOR UPDATE USING (is_editor() AND deleted_at IS NULL)
    WITH CHECK (is_editor());

-- Editors can soft-delete climbs
CREATE POLICY "climbs_delete" ON climbs
    FOR DELETE USING (is_editor());

-- ============================================================================
-- PITCHES TABLE
-- ============================================================================
-- Anyone can read pitches
CREATE POLICY "pitches_select" ON pitches
    FOR SELECT USING (true);

-- Editors can manage pitches
CREATE POLICY "pitches_insert" ON pitches
    FOR INSERT WITH CHECK (is_editor());

CREATE POLICY "pitches_update" ON pitches
    FOR UPDATE USING (is_editor())
    WITH CHECK (is_editor());

CREATE POLICY "pitches_delete" ON pitches
    FOR DELETE USING (is_editor());

-- ============================================================================
-- MEDIA TABLE (user-uploaded photos)
-- ============================================================================
-- Anyone can view non-deleted media
CREATE POLICY "media_select" ON media
    FOR SELECT USING (deleted_at IS NULL);

-- Authenticated users can upload their own media
CREATE POLICY "media_insert" ON media
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

-- Users can update their own media
CREATE POLICY "media_update" ON media
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Users can delete their own media
CREATE POLICY "media_delete" ON media
    FOR DELETE USING (user_id = auth.uid());

-- ============================================================================
-- ENTITY_TAGS TABLE (photo-to-climb/area links)
-- ============================================================================
-- Anyone can view tags
CREATE POLICY "entity_tags_select" ON entity_tags
    FOR SELECT USING (true);

-- Authenticated users can create tags (for their own media)
CREATE POLICY "entity_tags_insert" ON entity_tags
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND
        EXISTS (SELECT 1 FROM media WHERE id = media_id AND user_id = auth.uid())
    );

-- Users can update tags on their own media
CREATE POLICY "entity_tags_update" ON entity_tags
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM media WHERE id = media_id AND user_id = auth.uid())
    );

-- Users can delete tags on their own media
CREATE POLICY "entity_tags_delete" ON entity_tags
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM media WHERE id = media_id AND user_id = auth.uid())
    );

-- ============================================================================
-- TICKS TABLE (personal climbing log)
-- ============================================================================
-- Anyone can view non-deleted ticks (climbing is social!)
CREATE POLICY "ticks_select" ON ticks
    FOR SELECT USING (deleted_at IS NULL);

-- Authenticated users can log their own ticks
CREATE POLICY "ticks_insert" ON ticks
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

-- Users can update their own ticks
CREATE POLICY "ticks_update" ON ticks
    FOR UPDATE USING (user_id = auth.uid() AND deleted_at IS NULL)
    WITH CHECK (user_id = auth.uid());

-- Users can delete their own ticks
CREATE POLICY "ticks_delete" ON ticks
    FOR DELETE USING (user_id = auth.uid());

-- ============================================================================
-- ORGANIZATIONS TABLE
-- ============================================================================
-- Anyone can view non-deleted organizations
CREATE POLICY "orgs_select" ON organizations
    FOR SELECT USING (deleted_at IS NULL);

-- Only admins can manage organizations
CREATE POLICY "orgs_insert" ON organizations
    FOR INSERT WITH CHECK (is_admin());

CREATE POLICY "orgs_update" ON organizations
    FOR UPDATE USING (is_admin() AND deleted_at IS NULL)
    WITH CHECK (is_admin());

CREATE POLICY "orgs_delete" ON organizations
    FOR DELETE USING (is_admin());

-- ============================================================================
-- ORGANIZATION_AREAS TABLE
-- ============================================================================
-- Anyone can view org-area relationships
CREATE POLICY "org_areas_select" ON organization_areas
    FOR SELECT USING (true);

-- Only admins can manage org-area relationships
CREATE POLICY "org_areas_insert" ON organization_areas
    FOR INSERT WITH CHECK (is_admin());

CREATE POLICY "org_areas_update" ON organization_areas
    FOR UPDATE USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "org_areas_delete" ON organization_areas
    FOR DELETE USING (is_admin());

-- ============================================================================
-- HISTORY TABLE (audit log)
-- ============================================================================
-- Anyone can read history (transparency)
CREATE POLICY "history_select" ON history
    FOR SELECT USING (true);

-- History is written by triggers, not directly by users
-- No INSERT/UPDATE/DELETE policies = only triggers can write

-- ============================================================================
-- GRANT PERMISSIONS TO SUPABASE ROLES
-- ============================================================================
-- Supabase uses 'anon' and 'authenticated' roles

-- Grant read on all tables to both roles
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;

-- Grant write on specific tables to authenticated users
GRANT INSERT, UPDATE, DELETE ON users TO authenticated;
GRANT INSERT, UPDATE, DELETE ON ticks TO authenticated;
GRANT INSERT, UPDATE, DELETE ON media TO authenticated;
GRANT INSERT, UPDATE, DELETE ON entity_tags TO authenticated;

-- Grant write on content tables (RLS will enforce editor check)
GRANT INSERT, UPDATE, DELETE ON areas TO authenticated;
GRANT INSERT, UPDATE, DELETE ON climbs TO authenticated;
GRANT INSERT, UPDATE, DELETE ON pitches TO authenticated;
GRANT INSERT, UPDATE, DELETE ON organizations TO authenticated;
GRANT INSERT, UPDATE, DELETE ON organization_areas TO authenticated;

-- Grant execute on functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- SUMMARY
-- ============================================================================
--
-- | Table              | anon (read) | authenticated (read) | authenticated (write) |
-- |--------------------|-------------|---------------------|----------------------|
-- | users              | Yes         | Yes                 | Own profile only     |
-- | areas              | Yes         | Yes                 | Editors only         |
-- | climbs             | Yes         | Yes                 | Editors only         |
-- | pitches            | Yes         | Yes                 | Editors only         |
-- | media              | Yes         | Yes                 | Own media only       |
-- | entity_tags        | Yes         | Yes                 | Own media's tags     |
-- | ticks              | Yes         | Yes                 | Own ticks only       |
-- | organizations      | Yes         | Yes                 | Admins only          |
-- | organization_areas | Yes         | Yes                 | Admins only          |
-- | history            | Yes         | Yes                 | Triggers only        |
--
-- To make a user an editor: UPDATE users SET is_editor = true WHERE id = '...';
-- To make a user an admin:  UPDATE users SET is_admin = true WHERE id = '...';
