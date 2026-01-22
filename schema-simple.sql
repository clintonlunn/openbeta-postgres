-- OpenBeta PostgreSQL Schema (Simplified)
-- Minimal POC: 4 tables, easy to understand

-- ============================================================================
-- EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "ltree";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- USERS
-- ============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE,
    display_name TEXT,
    avatar_url TEXT,
    external_auth_id TEXT UNIQUE,  -- Auth0 user ID
    is_editor BOOLEAN DEFAULT FALSE,
    is_admin BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX users_external_auth_idx ON users(external_auth_id);

-- ============================================================================
-- AREAS (hierarchical locations)
-- ============================================================================
CREATE TABLE areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES areas(id),
    name TEXT NOT NULL,

    -- Hierarchy
    path ltree,                    -- 'usa.california.yosemite'
    path_tokens TEXT[],            -- ['USA', 'California', 'Yosemite']

    -- Location
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,

    -- Classification
    is_leaf BOOLEAN DEFAULT FALSE, -- Leaf areas contain climbs
    total_climbs INT DEFAULT 0,    -- Aggregated count

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX areas_parent_idx ON areas(parent_id);
CREATE INDEX areas_path_idx ON areas USING GIST(path);
CREATE INDEX areas_name_idx ON areas USING GIN(name gin_trgm_ops);

-- ============================================================================
-- CLIMBS
-- ============================================================================
CREATE TABLE climbs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    area_id UUID NOT NULL REFERENCES areas(id),
    name TEXT NOT NULL,

    -- Grades (most common systems)
    grade_yds TEXT,      -- 5.10a, 5.12c
    grade_vscale TEXT,   -- V0, V10
    grade_french TEXT,   -- 6a, 7c+
    grade_font TEXT,     -- 6A, 7C+ (bouldering)

    -- Disciplines
    is_sport BOOLEAN DEFAULT FALSE,
    is_trad BOOLEAN DEFAULT FALSE,
    is_boulder BOOLEAN DEFAULT FALSE,

    -- Details
    length_meters INT,
    pitch_count INT DEFAULT 1,
    fa TEXT,             -- First ascent
    description TEXT,

    -- Location
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX climbs_area_idx ON climbs(area_id);
CREATE INDEX climbs_name_idx ON climbs USING GIN(name gin_trgm_ops);
CREATE INDEX climbs_grade_yds_idx ON climbs(grade_yds) WHERE grade_yds IS NOT NULL;
CREATE INDEX climbs_grade_vscale_idx ON climbs(grade_vscale) WHERE grade_vscale IS NOT NULL;

-- ============================================================================
-- TICKS (user climbing log)
-- ============================================================================
CREATE TABLE ticks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    climb_id UUID REFERENCES climbs(id) ON DELETE SET NULL,
    climb_name TEXT NOT NULL,      -- Denormalized for display
    grade TEXT,                    -- Denormalized
    date_climbed DATE NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ticks_user_idx ON ticks(user_id);
CREATE INDEX ticks_climb_idx ON ticks(climb_id) WHERE climb_id IS NOT NULL;
CREATE INDEX ticks_date_idx ON ticks(user_id, date_climbed DESC);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Climbs with area info
CREATE VIEW climbs_with_area AS
SELECT
    c.*,
    a.name AS area_name,
    a.path_tokens,
    a.path_tokens[1] AS country,
    a.path_tokens[2] AS region
FROM climbs c
JOIN areas a ON c.area_id = a.id;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Get current user from JWT (supports Supabase Auth + Auth0)
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
        NULL;
    END;

    -- Try Auth0 JWT claims
    BEGIN
        jwt_sub := current_setting('request.jwt.claims', true)::json->>'sub';
        IF jwt_sub IS NOT NULL AND jwt_sub != '' THEN
            SELECT id INTO user_uuid FROM users WHERE external_auth_id = jwt_sub;
            RETURN user_uuid;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Check if current user is editor
CREATE OR REPLACE FUNCTION is_editor() RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM users WHERE id = current_user_id() AND is_editor = true);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Search climbs
CREATE OR REPLACE FUNCTION search_climbs(p_query TEXT, p_limit INT DEFAULT 50)
RETURNS TABLE (
    id UUID, name TEXT, grade_yds TEXT, grade_vscale TEXT,
    area_id UUID, area_name TEXT, path_tokens TEXT[], similarity REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.name, c.grade_yds, c.grade_vscale, c.area_id,
           a.name AS area_name, a.path_tokens, similarity(c.name, p_query) AS similarity
    FROM climbs c
    JOIN areas a ON c.area_id = a.id
    WHERE c.name % p_query
    ORDER BY similarity(c.name, p_query) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Search areas
CREATE OR REPLACE FUNCTION search_areas(p_query TEXT, p_limit INT DEFAULT 50)
RETURNS TABLE (id UUID, name TEXT, path_tokens TEXT[], is_leaf BOOLEAN, total_climbs INT, similarity REAL) AS $$
BEGIN
    RETURN QUERY
    SELECT a.id, a.name, a.path_tokens, a.is_leaf, a.total_climbs, similarity(a.name, p_query) AS similarity
    FROM areas a
    WHERE a.name % p_query
    ORDER BY similarity(a.name, p_query) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE climbs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticks ENABLE ROW LEVEL SECURITY;

-- Public read access
CREATE POLICY "public_read_areas" ON areas FOR SELECT USING (true);
CREATE POLICY "public_read_climbs" ON climbs FOR SELECT USING (true);
CREATE POLICY "public_read_users" ON users FOR SELECT USING (true);
CREATE POLICY "public_read_ticks" ON ticks FOR SELECT USING (true);

-- Users manage own profile
CREATE POLICY "users_update_own" ON users FOR UPDATE
    USING (id = current_user_id()) WITH CHECK (id = current_user_id());

-- Users manage own ticks
CREATE POLICY "ticks_insert" ON ticks FOR INSERT
    WITH CHECK (current_user_id() IS NOT NULL AND user_id = current_user_id());
CREATE POLICY "ticks_update" ON ticks FOR UPDATE
    USING (user_id = current_user_id()) WITH CHECK (user_id = current_user_id());
CREATE POLICY "ticks_delete" ON ticks FOR DELETE
    USING (user_id = current_user_id());

-- Editors manage climbing data
CREATE POLICY "editors_manage_areas" ON areas FOR ALL
    USING (is_editor()) WITH CHECK (is_editor());
CREATE POLICY "editors_manage_climbs" ON climbs FOR ALL
    USING (is_editor()) WITH CHECK (is_editor());
