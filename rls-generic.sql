-- OpenBeta RLS Policies - Provider Agnostic
-- Works with any PostgREST setup (Supabase, self-hosted, Neon, etc.)
--
-- Security Model:
-- 1. Public data (areas, climbs, orgs) - readable by everyone (anon + authenticated)
-- 2. User data (ticks, media) - users can only access their own
-- 3. Editor role - can modify climbing data (areas, climbs)
-- 4. Admin role - can manage organizations and users
--
-- Provider-specific: Only the current_user_id() function needs customization

-- ============================================================================
-- HELPER FUNCTION: Get current user ID from JWT
-- ============================================================================
-- This extracts the user ID from PostgREST JWT claims
-- Customize this for your auth provider:
--   - Supabase: auth.uid()
--   - Auth0: current_setting('request.jwt.claims', true)::json->>'sub'
--   - Custom: adjust the claim path as needed
CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID AS $$
DECLARE
    jwt_claims JSON;
    user_id TEXT;
BEGIN
    -- Try Supabase's auth.uid() first
    BEGIN
        RETURN auth.uid();
    EXCEPTION WHEN undefined_function THEN
        -- Fall back to standard PostgREST JWT claims
        NULL;
    END;

    -- Standard PostgREST: extract from JWT claims
    BEGIN
        jwt_claims := current_setting('request.jwt.claims', true)::JSON;
        -- Try common claim names
        user_id := COALESCE(
            jwt_claims->>'sub',           -- Standard JWT subject
            jwt_claims->>'user_id',       -- Custom claim
            jwt_claims->>'id'             -- Alternative
        );
        IF user_id IS NOT NULL AND user_id != '' THEN
            RETURN user_id::UUID;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- HELPER FUNCTION: Check if current user is an editor
-- ============================================================================
CREATE OR REPLACE FUNCTION is_editor() RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = current_user_id()
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
        WHERE id = current_user_id()
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
CREATE POLICY "users_select" ON users
    FOR SELECT USING (deleted_at IS NULL);

CREATE POLICY "users_update_own" ON users
    FOR UPDATE USING (id = current_user_id())
    WITH CHECK (id = current_user_id());

CREATE POLICY "users_insert_own" ON users
    FOR INSERT WITH CHECK (id = current_user_id());

-- ============================================================================
-- AREAS TABLE (public climbing data)
-- ============================================================================
CREATE POLICY "areas_select" ON areas
    FOR SELECT USING (deleted_at IS NULL);

CREATE POLICY "areas_insert" ON areas
    FOR INSERT WITH CHECK (is_editor());

CREATE POLICY "areas_update" ON areas
    FOR UPDATE USING (is_editor() AND deleted_at IS NULL)
    WITH CHECK (is_editor());

CREATE POLICY "areas_delete" ON areas
    FOR DELETE USING (is_editor());

-- ============================================================================
-- CLIMBS TABLE (public climbing data)
-- ============================================================================
CREATE POLICY "climbs_select" ON climbs
    FOR SELECT USING (deleted_at IS NULL);

CREATE POLICY "climbs_insert" ON climbs
    FOR INSERT WITH CHECK (is_editor());

CREATE POLICY "climbs_update" ON climbs
    FOR UPDATE USING (is_editor() AND deleted_at IS NULL)
    WITH CHECK (is_editor());

CREATE POLICY "climbs_delete" ON climbs
    FOR DELETE USING (is_editor());

-- ============================================================================
-- PITCHES TABLE
-- ============================================================================
CREATE POLICY "pitches_select" ON pitches
    FOR SELECT USING (true);

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
CREATE POLICY "media_select" ON media
    FOR SELECT USING (deleted_at IS NULL);

CREATE POLICY "media_insert" ON media
    FOR INSERT WITH CHECK (current_user_id() IS NOT NULL AND user_id = current_user_id());

CREATE POLICY "media_update" ON media
    FOR UPDATE USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

CREATE POLICY "media_delete" ON media
    FOR DELETE USING (user_id = current_user_id());

-- ============================================================================
-- ENTITY_TAGS TABLE (photo-to-climb/area links)
-- ============================================================================
CREATE POLICY "entity_tags_select" ON entity_tags
    FOR SELECT USING (true);

CREATE POLICY "entity_tags_insert" ON entity_tags
    FOR INSERT WITH CHECK (
        current_user_id() IS NOT NULL AND
        EXISTS (SELECT 1 FROM media WHERE id = media_id AND user_id = current_user_id())
    );

CREATE POLICY "entity_tags_update" ON entity_tags
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM media WHERE id = media_id AND user_id = current_user_id())
    );

CREATE POLICY "entity_tags_delete" ON entity_tags
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM media WHERE id = media_id AND user_id = current_user_id())
    );

-- ============================================================================
-- TICKS TABLE (personal climbing log)
-- ============================================================================
CREATE POLICY "ticks_select" ON ticks
    FOR SELECT USING (deleted_at IS NULL);

CREATE POLICY "ticks_insert" ON ticks
    FOR INSERT WITH CHECK (current_user_id() IS NOT NULL AND user_id = current_user_id());

CREATE POLICY "ticks_update" ON ticks
    FOR UPDATE USING (user_id = current_user_id() AND deleted_at IS NULL)
    WITH CHECK (user_id = current_user_id());

CREATE POLICY "ticks_delete" ON ticks
    FOR DELETE USING (user_id = current_user_id());

-- ============================================================================
-- ORGANIZATIONS TABLE
-- ============================================================================
CREATE POLICY "orgs_select" ON organizations
    FOR SELECT USING (deleted_at IS NULL);

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
CREATE POLICY "org_areas_select" ON organization_areas
    FOR SELECT USING (true);

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
CREATE POLICY "history_select" ON history
    FOR SELECT USING (true);

-- ============================================================================
-- GRANTS FOR POSTGREST ROLES
-- ============================================================================
-- Standard PostgREST uses 'anon' and 'authenticator' roles
-- Adjust these if your provider uses different role names

-- Create roles if they don't exist (may fail on managed providers - that's OK)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL; -- Ignore errors on managed providers
END $$;

-- Grant read on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;

-- Grant write on user-owned tables
GRANT INSERT, UPDATE, DELETE ON users TO authenticated;
GRANT INSERT, UPDATE, DELETE ON ticks TO authenticated;
GRANT INSERT, UPDATE, DELETE ON media TO authenticated;
GRANT INSERT, UPDATE, DELETE ON entity_tags TO authenticated;

-- Grant write on content tables (RLS enforces editor check)
GRANT INSERT, UPDATE, DELETE ON areas TO authenticated;
GRANT INSERT, UPDATE, DELETE ON climbs TO authenticated;
GRANT INSERT, UPDATE, DELETE ON pitches TO authenticated;
GRANT INSERT, UPDATE, DELETE ON organizations TO authenticated;
GRANT INSERT, UPDATE, DELETE ON organization_areas TO authenticated;

-- Grant execute on functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- PROVIDER-SPECIFIC NOTES
-- ============================================================================
--
-- SUPABASE:
--   - Uses auth.uid() automatically (handled by current_user_id fallback)
--   - Roles 'anon' and 'authenticated' are pre-configured
--   - Run as-is
--
-- NEON + PostgREST:
--   - Set PGRST_JWT_SECRET in PostgREST config
--   - JWT should include 'sub' claim with user UUID
--   - May need to create anon/authenticated roles
--
-- SELF-HOSTED PostgREST:
--   - Configure JWT secret and claims
--   - Create authenticator role: CREATE ROLE authenticator LOGIN;
--   - Grant roles: GRANT anon, authenticated TO authenticator;
--
-- ============================================================================
-- SUMMARY
-- ============================================================================
--
-- | Table              | anon | authenticated | Editor | Admin |
-- |--------------------|------|---------------|--------|-------|
-- | areas              | R    | R             | CRUD   | CRUD  |
-- | climbs             | R    | R             | CRUD   | CRUD  |
-- | pitches            | R    | R             | CRUD   | CRUD  |
-- | media              | R    | R (own)       | own    | own   |
-- | entity_tags        | R    | R (own)       | own    | own   |
-- | ticks              | R    | R (own)       | own    | own   |
-- | organizations      | R    | R             | R      | CRUD  |
-- | organization_areas | R    | R             | R      | CRUD  |
-- | history            | R    | R             | R      | R     |
-- | users              | R    | R (own edit)  | own    | own   |
--
-- To make a user an editor: UPDATE users SET is_editor = true WHERE id = '...';
-- To make a user an admin:  UPDATE users SET is_admin = true WHERE id = '...';
