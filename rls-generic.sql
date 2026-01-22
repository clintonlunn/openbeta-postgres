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
-- Supports both Supabase Auth and Auth0/external providers
-- For Auth0: looks up user by external_auth_id and returns internal UUID
CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID AS $$
DECLARE
    supabase_uid UUID;
    jwt_sub TEXT;
    user_uuid UUID;
BEGIN
    -- Try Supabase Auth first
    BEGIN
        supabase_uid := auth.uid();
        IF supabase_uid IS NOT NULL THEN
            RETURN supabase_uid;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- auth.uid() not available, continue to JWT extraction
        NULL;
    END;

    -- Try extracting from PostgREST JWT claims (for Auth0/external providers)
    BEGIN
        jwt_sub := current_setting('request.jwt.claims', true)::json->>'sub';

        IF jwt_sub IS NOT NULL AND jwt_sub != '' THEN
            -- Look up user by external_auth_id and return their internal UUID
            SELECT id INTO user_uuid
            FROM users
            WHERE external_auth_id = jwt_sub
            AND deleted_at IS NULL;

            RETURN user_uuid;
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
