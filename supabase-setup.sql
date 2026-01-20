-- Run this in Supabase SQL Editor to set up the schema
-- This creates all tables, functions, triggers needed for OpenBeta

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS ltree;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- OpenBeta PostgreSQL Schema v2
-- Wiki-style architecture: current state + full history + revert capability
-- Designed for PostgREST

-- ============================================================================
-- EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "ltree";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- fuzzy text search

-- ============================================================================
-- ENUMS
-- ============================================================================
CREATE TYPE safety_rating AS ENUM ('UNSPECIFIED', 'PG', 'PG13', 'R', 'X');
CREATE TYPE tick_style AS ENUM ('Lead', 'Solo', 'TR', 'Follow', 'Aid', 'Boulder');
CREATE TYPE tick_attempt AS ENUM ('Onsight', 'Flash', 'Pinkpoint', 'Frenchfree', 'Send', 'Attempt', 'Redpoint', 'Repeat');
CREATE TYPE tick_source AS ENUM ('OB', 'MP');
CREATE TYPE org_type AS ENUM ('local_climbing_org', 'gym');
CREATE TYPE history_operation AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- Grade context determines which grading system is primary for an area
-- US = YDS/V-scale, FR = French/Font, UIAA = UIAA/Font, etc.
CREATE TYPE grade_context AS ENUM ('US', 'FR', 'UIAA', 'AU', 'SA', 'UK', 'FI', 'NWG', 'SXG', 'BRZ');

-- ============================================================================
-- USERS
-- ============================================================================
-- Users table first since other tables reference it
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE,  -- required on first profile creation
    display_name TEXT,
    bio TEXT,
    website TEXT,
    avatar_url TEXT,

    -- external auth reference (Auth0, etc.)
    external_auth_id TEXT UNIQUE,

    -- roles (used by RLS)
    is_editor BOOLEAN DEFAULT FALSE,
    is_admin BOOLEAN DEFAULT FALSE,

    -- versioning
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ  -- soft delete
);

CREATE INDEX users_username_idx ON users(username) WHERE deleted_at IS NULL;
CREATE INDEX users_external_auth_idx ON users(external_auth_id) WHERE deleted_at IS NULL;

-- ============================================================================
-- AREAS (hierarchical)
-- ============================================================================
CREATE TABLE areas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES areas(id) ON DELETE RESTRICT,  -- prevent accidental cascade

    -- identity
    name TEXT NOT NULL,
    short_code TEXT,  -- globally unique short codes for major areas

    -- hierarchy (ltree for efficient ancestor/descendant queries)
    path ltree,  -- e.g., 'usa.california.yosemite'
    path_tokens TEXT[],  -- ['USA', 'California', 'Yosemite'] - human readable

    -- grade context (inherited by children if not set)
    grade_context grade_context,

    -- location
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    bbox DOUBLE PRECISION[4],  -- [min_lng, min_lat, max_lng, max_lat]
    polygon JSONB,  -- GeoJSON polygon for area boundary

    -- classification
    is_destination BOOLEAN NOT NULL DEFAULT FALSE,
    is_leaf BOOLEAN NOT NULL DEFAULT FALSE,  -- leaf nodes contain climbs directly
    is_boulder BOOLEAN,  -- if leaf, is this a boulder (vs crag/wall)?

    -- ordering
    left_right_index INT,

    -- content
    description TEXT,
    area_location TEXT,  -- approach/location beta

    -- aggregates (updated by triggers or periodic job)
    total_climbs INT NOT NULL DEFAULT 0,
    density DOUBLE PRECISION,  -- climbs per sq km

    -- legacy external IDs
    mp_id TEXT,

    -- versioning & audit
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX areas_parent_id_idx ON areas(parent_id) WHERE deleted_at IS NULL;
CREATE INDEX areas_path_gist_idx ON areas USING GIST(path) WHERE deleted_at IS NULL;
CREATE INDEX areas_path_btree_idx ON areas USING BTREE(path) WHERE deleted_at IS NULL;
CREATE INDEX areas_name_trgm_idx ON areas USING GIN(name gin_trgm_ops) WHERE deleted_at IS NULL;
CREATE INDEX areas_coords_idx ON areas(lat, lng) WHERE lat IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX areas_is_leaf_idx ON areas(is_leaf) WHERE deleted_at IS NULL;
CREATE INDEX areas_short_code_idx ON areas(short_code) WHERE short_code IS NOT NULL AND deleted_at IS NULL;

-- ============================================================================
-- CLIMBS
-- ============================================================================
CREATE TABLE climbs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    area_id UUID NOT NULL REFERENCES areas(id) ON DELETE RESTRICT,

    -- identity
    name TEXT NOT NULL,

    -- grades (separate columns for queryability, NULL if not applicable)
    grade_yds TEXT,          -- 5.10a, 5.12c, etc.
    grade_vscale TEXT,       -- V0, V10, etc.
    grade_french TEXT,       -- 6a, 7c+, etc.
    grade_font TEXT,         -- 6A, 7C+, etc. (bouldering)
    grade_ewbank TEXT,       -- Australian/NZ system
    grade_uiaa TEXT,         -- European trad
    grade_brazilian_crux TEXT,
    grade_wi TEXT,           -- water ice
    grade_ai TEXT,           -- alpine ice
    grade_aid TEXT,          -- A0-A5, C0-C5

    -- disciplines (multiple can be true)
    is_trad BOOLEAN NOT NULL DEFAULT FALSE,
    is_sport BOOLEAN NOT NULL DEFAULT FALSE,
    is_boulder BOOLEAN NOT NULL DEFAULT FALSE,
    is_dws BOOLEAN NOT NULL DEFAULT FALSE,      -- deep water solo
    is_alpine BOOLEAN NOT NULL DEFAULT FALSE,
    is_snow BOOLEAN NOT NULL DEFAULT FALSE,
    is_ice BOOLEAN NOT NULL DEFAULT FALSE,
    is_mixed BOOLEAN NOT NULL DEFAULT FALSE,
    is_aid BOOLEAN NOT NULL DEFAULT FALSE,
    is_tr BOOLEAN NOT NULL DEFAULT FALSE,       -- top rope only

    -- details
    length_meters INT,
    pitch_count INT DEFAULT 1,
    bolts_count INT,
    fa TEXT,  -- first ascent info
    safety safety_rating NOT NULL DEFAULT 'UNSPECIFIED',

    -- location (can differ from area centroid)
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    left_right_index INT,

    -- content
    description TEXT,
    location TEXT,      -- how to find the climb
    protection TEXT,    -- gear beta

    -- legacy
    mp_id TEXT,

    -- versioning & audit
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX climbs_area_id_idx ON climbs(area_id) WHERE deleted_at IS NULL;
CREATE INDEX climbs_name_trgm_idx ON climbs USING GIN(name gin_trgm_ops) WHERE deleted_at IS NULL;
CREATE INDEX climbs_grade_yds_idx ON climbs(grade_yds) WHERE grade_yds IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX climbs_grade_vscale_idx ON climbs(grade_vscale) WHERE grade_vscale IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX climbs_grade_french_idx ON climbs(grade_french) WHERE grade_french IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX climbs_disciplines_idx ON climbs(is_sport, is_trad, is_boulder) WHERE deleted_at IS NULL;
CREATE INDEX climbs_coords_idx ON climbs(lat, lng) WHERE lat IS NOT NULL AND deleted_at IS NULL;

-- Constraint: climb must belong to a leaf area
-- (enforced by trigger since we need to check parent)

-- ============================================================================
-- PITCHES (for multi-pitch routes)
-- ============================================================================
CREATE TABLE pitches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    climb_id UUID NOT NULL REFERENCES climbs(id) ON DELETE CASCADE,
    pitch_number INT NOT NULL,

    -- grades can differ per pitch
    grade_yds TEXT,
    grade_vscale TEXT,
    grade_french TEXT,
    grade_aid TEXT,

    -- discipline can differ per pitch
    is_trad BOOLEAN,
    is_sport BOOLEAN,
    is_aid BOOLEAN,

    -- details
    length_meters INT,
    bolts_count INT,
    description TEXT,

    -- versioning
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(climb_id, pitch_number)
);

CREATE INDEX pitches_climb_id_idx ON pitches(climb_id);

-- ============================================================================
-- MEDIA
-- ============================================================================
CREATE TABLE media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    url TEXT NOT NULL,
    width INT NOT NULL,
    height INT NOT NULL,
    format TEXT NOT NULL,  -- jpeg, png, webp, avif
    size_bytes INT,

    -- versioning
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX media_user_id_idx ON media(user_id) WHERE deleted_at IS NULL;

-- ============================================================================
-- ENTITY TAGS (linking media to climbs/areas with optional topo data)
-- ============================================================================
CREATE TABLE entity_tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    media_id UUID NOT NULL REFERENCES media(id) ON DELETE CASCADE,

    -- polymorphic reference (exactly one must be set)
    climb_id UUID REFERENCES climbs(id) ON DELETE CASCADE,
    area_id UUID REFERENCES areas(id) ON DELETE CASCADE,

    -- topo annotation data (lines, markers on the photo)
    topo_data JSONB,

    -- audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),

    CONSTRAINT tag_has_one_target CHECK (
        (climb_id IS NOT NULL AND area_id IS NULL) OR
        (climb_id IS NULL AND area_id IS NOT NULL)
    )
);

CREATE INDEX entity_tags_media_id_idx ON entity_tags(media_id);
CREATE INDEX entity_tags_climb_id_idx ON entity_tags(climb_id) WHERE climb_id IS NOT NULL;
CREATE INDEX entity_tags_area_id_idx ON entity_tags(area_id) WHERE area_id IS NOT NULL;

-- ============================================================================
-- TICKS (user climbing log)
-- ============================================================================
CREATE TABLE ticks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    climb_id UUID REFERENCES climbs(id) ON DELETE SET NULL,

    -- denormalized for when climb is deleted or imported from external source
    climb_name TEXT NOT NULL,
    grade TEXT,

    -- tick details
    style tick_style,
    attempt_type tick_attempt,
    date_climbed DATE NOT NULL,
    notes TEXT,

    -- source tracking
    source tick_source NOT NULL DEFAULT 'OB',

    -- versioning
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX ticks_user_id_idx ON ticks(user_id) WHERE deleted_at IS NULL;
CREATE INDEX ticks_climb_id_idx ON ticks(climb_id) WHERE climb_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX ticks_date_idx ON ticks(date_climbed) WHERE deleted_at IS NULL;
CREATE INDEX ticks_user_date_idx ON ticks(user_id, date_climbed DESC) WHERE deleted_at IS NULL;

-- ============================================================================
-- ORGANIZATIONS
-- ============================================================================
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_type org_type NOT NULL,
    display_name TEXT NOT NULL,

    -- contact/links
    website TEXT,
    email TEXT,
    donation_link TEXT,
    instagram TEXT,
    facebook TEXT,
    hardware_report_link TEXT,

    description TEXT,

    -- versioning & audit
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX organizations_name_trgm_idx ON organizations USING GIN(display_name gin_trgm_ops) WHERE deleted_at IS NULL;

-- Organization <-> Area relationships
CREATE TABLE organization_areas (
    org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    area_id UUID NOT NULL REFERENCES areas(id) ON DELETE CASCADE,
    is_excluded BOOLEAN NOT NULL DEFAULT FALSE,  -- TRUE = org explicitly excludes this area

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (org_id, area_id)
);

CREATE INDEX organization_areas_area_idx ON organization_areas(area_id);

-- ============================================================================
-- HISTORY TABLES (wiki-style versioning)
-- ============================================================================

-- Generic history table for all entities
-- Stores complete snapshots as JSONB for simplicity
CREATE TABLE history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- what changed
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    version INT NOT NULL,

    -- the change
    operation history_operation NOT NULL,
    old_data JSONB,
    new_data JSONB,

    -- who/when
    changed_by UUID REFERENCES users(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- optional: changeset grouping for related edits
    changeset_id UUID,
    change_comment TEXT
);

CREATE INDEX history_record_idx ON history(table_name, record_id);
CREATE INDEX history_record_version_idx ON history(table_name, record_id, version);
CREATE INDEX history_changed_by_idx ON history(changed_by);
CREATE INDEX history_changed_at_idx ON history(changed_at);
CREATE INDEX history_changeset_idx ON history(changeset_id) WHERE changeset_id IS NOT NULL;

-- ============================================================================
-- VIEWS (for PostgREST endpoints)
-- ============================================================================

-- Active areas (excludes soft-deleted)
CREATE VIEW areas_active AS
SELECT * FROM areas WHERE deleted_at IS NULL;

-- Active climbs (excludes soft-deleted)
CREATE VIEW climbs_active AS
SELECT * FROM climbs WHERE deleted_at IS NULL;

-- Climbs with full area context (replaces denormalized columns)
CREATE VIEW climbs_with_context AS
SELECT
    c.*,
    a.name AS area_name,
    a.path_tokens,
    a.path,
    a.grade_context AS area_grade_context,
    -- Extract hierarchy levels from path_tokens
    a.path_tokens[1] AS country,
    a.path_tokens[2] AS region,
    a.path_tokens[3] AS sub_region,
    COALESCE(a.lat, c.lat) AS effective_lat,
    COALESCE(a.lng, c.lng) AS effective_lng
FROM climbs c
JOIN areas a ON c.area_id = a.id
WHERE c.deleted_at IS NULL AND a.deleted_at IS NULL;

-- Areas with computed ancestor chain
CREATE VIEW areas_with_ancestors AS
SELECT
    a.*,
    (
        SELECT jsonb_agg(jsonb_build_object('id', a2.id, 'name', a2.name) ORDER BY nlevel(a2.path))
        FROM areas a2
        WHERE a.path <@ a2.path AND a2.deleted_at IS NULL
    ) AS ancestors
FROM areas a
WHERE a.deleted_at IS NULL;

-- Area children (for navigation)
CREATE VIEW area_children AS
SELECT
    parent_id,
    id,
    name,
    is_leaf,
    is_boulder,
    total_climbs,
    left_right_index
FROM areas
WHERE deleted_at IS NULL AND parent_id IS NOT NULL
ORDER BY COALESCE(left_right_index, 999999), name;

-- User public profiles (safe to expose)
CREATE VIEW user_profiles AS
SELECT
    id,
    username,
    display_name,
    bio,
    website,
    avatar_url,
    created_at
FROM users
WHERE deleted_at IS NULL;

-- Ticks with climb info
CREATE VIEW ticks_with_context AS
SELECT
    t.*,
    u.username,
    u.display_name AS user_display_name,
    c.area_id,
    a.name AS area_name,
    a.path_tokens
FROM ticks t
JOIN users u ON t.user_id = u.id
LEFT JOIN climbs c ON t.climb_id = c.id
LEFT JOIN areas a ON c.area_id = a.id
WHERE t.deleted_at IS NULL;

-- ============================================================================
-- FUNCTIONS: History Recording
-- ============================================================================

-- Get current user from PostgREST JWT claim
CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('request.jwt.claims', true)::json->>'sub', '')::UUID;
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- Generic history recording function
CREATE OR REPLACE FUNCTION record_history() RETURNS TRIGGER AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
    v_user_id UUID;
BEGIN
    v_user_id := current_user_id();

    IF TG_OP = 'DELETE' THEN
        v_old_data := to_jsonb(OLD);
        INSERT INTO history (table_name, record_id, version, operation, old_data, changed_by)
        VALUES (TG_TABLE_NAME, OLD.id, OLD.version, 'DELETE', v_old_data, v_user_id);
        RETURN OLD;

    ELSIF TG_OP = 'UPDATE' THEN
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);

        -- Only record if something actually changed (ignore version/updated_at)
        IF v_old_data - 'version' - 'updated_at' IS DISTINCT FROM v_new_data - 'version' - 'updated_at' THEN
            INSERT INTO history (table_name, record_id, version, operation, old_data, new_data, changed_by)
            VALUES (TG_TABLE_NAME, OLD.id, OLD.version, 'UPDATE', v_old_data, v_new_data, v_user_id);
        END IF;

        NEW.version := OLD.version + 1;
        NEW.updated_at := NOW();
        NEW.updated_by := v_user_id;
        RETURN NEW;

    ELSIF TG_OP = 'INSERT' THEN
        v_new_data := to_jsonb(NEW);
        INSERT INTO history (table_name, record_id, version, operation, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.id, NEW.version, 'INSERT', v_new_data, v_user_id);

        NEW.created_by := COALESCE(NEW.created_by, v_user_id);
        NEW.updated_by := COALESCE(NEW.updated_by, v_user_id);
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply history triggers to main tables
CREATE TRIGGER areas_history_trigger
    BEFORE INSERT OR UPDATE OR DELETE ON areas
    FOR EACH ROW EXECUTE FUNCTION record_history();

CREATE TRIGGER climbs_history_trigger
    BEFORE INSERT OR UPDATE OR DELETE ON climbs
    FOR EACH ROW EXECUTE FUNCTION record_history();

CREATE TRIGGER organizations_history_trigger
    BEFORE INSERT OR UPDATE OR DELETE ON organizations
    FOR EACH ROW EXECUTE FUNCTION record_history();

-- ============================================================================
-- FUNCTIONS: Area Stats Updates
-- ============================================================================

-- Update total_climbs count for an area and all ancestors
CREATE OR REPLACE FUNCTION update_area_stats(p_area_id UUID) RETURNS VOID AS $$
DECLARE
    v_path ltree;
BEGIN
    -- Get the path of the area
    SELECT path INTO v_path FROM areas WHERE id = p_area_id;

    -- Update this area and all ancestors
    UPDATE areas a
    SET total_climbs = (
        SELECT COUNT(*)
        FROM climbs c
        JOIN areas leaf ON c.area_id = leaf.id
        WHERE leaf.path <@ a.path
        AND c.deleted_at IS NULL
        AND leaf.deleted_at IS NULL
    )
    WHERE a.path @> v_path OR a.path = v_path;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update stats when climbs change
CREATE OR REPLACE FUNCTION climbs_stats_trigger() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND OLD.area_id IS DISTINCT FROM NEW.area_id) THEN
        PERFORM update_area_stats(OLD.area_id);
    END IF;

    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.area_id IS DISTINCT FROM NEW.area_id) THEN
        PERFORM update_area_stats(NEW.area_id);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER climbs_stats_trigger
    AFTER INSERT OR UPDATE OR DELETE ON climbs
    FOR EACH ROW EXECUTE FUNCTION climbs_stats_trigger();

-- ============================================================================
-- FUNCTIONS: Grade Context Inheritance
-- ============================================================================

-- Get effective grade context for a climb (inherits from area hierarchy)
CREATE OR REPLACE FUNCTION get_grade_context(p_area_id UUID)
RETURNS grade_context AS $$
DECLARE
    v_context grade_context;
BEGIN
    -- Walk up the tree to find first non-null grade_context
    SELECT a.grade_context INTO v_context
    FROM areas target
    JOIN areas a ON target.path <@ a.path
    WHERE target.id = p_area_id
    AND a.grade_context IS NOT NULL
    AND a.deleted_at IS NULL
    ORDER BY nlevel(a.path) DESC
    LIMIT 1;

    RETURN COALESCE(v_context, 'US');  -- default to US
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- FUNCTIONS: Revert (Wiki-style undo)
-- ============================================================================

-- Revert an area to a previous version
CREATE OR REPLACE FUNCTION revert_area(
    p_area_id UUID,
    p_to_version INT
) RETURNS areas AS $$
DECLARE
    v_old_data JSONB;
    v_result areas;
BEGIN
    -- Get the historical data
    SELECT old_data INTO v_old_data
    FROM history
    WHERE table_name = 'areas'
    AND record_id = p_area_id
    AND version = p_to_version;

    IF v_old_data IS NULL THEN
        RAISE EXCEPTION 'Version % not found for area %', p_to_version, p_area_id;
    END IF;

    -- Update the area with historical data
    UPDATE areas SET
        name = v_old_data->>'name',
        short_code = v_old_data->>'short_code',
        description = v_old_data->>'description',
        area_location = v_old_data->>'area_location',
        lat = (v_old_data->>'lat')::DOUBLE PRECISION,
        lng = (v_old_data->>'lng')::DOUBLE PRECISION,
        is_destination = (v_old_data->>'is_destination')::BOOLEAN,
        is_leaf = (v_old_data->>'is_leaf')::BOOLEAN,
        is_boulder = (v_old_data->>'is_boulder')::BOOLEAN,
        left_right_index = (v_old_data->>'left_right_index')::INT
        -- Note: we don't revert structural fields like parent_id, path
    WHERE id = p_area_id
    RETURNING * INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Revert a climb to a previous version
CREATE OR REPLACE FUNCTION revert_climb(
    p_climb_id UUID,
    p_to_version INT
) RETURNS climbs AS $$
DECLARE
    v_old_data JSONB;
    v_result climbs;
BEGIN
    SELECT old_data INTO v_old_data
    FROM history
    WHERE table_name = 'climbs'
    AND record_id = p_climb_id
    AND version = p_to_version;

    IF v_old_data IS NULL THEN
        RAISE EXCEPTION 'Version % not found for climb %', p_to_version, p_climb_id;
    END IF;

    UPDATE climbs SET
        name = v_old_data->>'name',
        grade_yds = v_old_data->>'grade_yds',
        grade_vscale = v_old_data->>'grade_vscale',
        grade_french = v_old_data->>'grade_french',
        grade_font = v_old_data->>'grade_font',
        is_trad = (v_old_data->>'is_trad')::BOOLEAN,
        is_sport = (v_old_data->>'is_sport')::BOOLEAN,
        is_boulder = (v_old_data->>'is_boulder')::BOOLEAN,
        is_dws = (v_old_data->>'is_dws')::BOOLEAN,
        is_alpine = (v_old_data->>'is_alpine')::BOOLEAN,
        is_ice = (v_old_data->>'is_ice')::BOOLEAN,
        is_mixed = (v_old_data->>'is_mixed')::BOOLEAN,
        is_aid = (v_old_data->>'is_aid')::BOOLEAN,
        is_tr = (v_old_data->>'is_tr')::BOOLEAN,
        length_meters = (v_old_data->>'length_meters')::INT,
        pitch_count = (v_old_data->>'pitch_count')::INT,
        bolts_count = (v_old_data->>'bolts_count')::INT,
        fa = v_old_data->>'fa',
        safety = (v_old_data->>'safety')::safety_rating,
        description = v_old_data->>'description',
        location = v_old_data->>'location',
        protection = v_old_data->>'protection'
    WHERE id = p_climb_id
    RETURNING * INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCTIONS: Search (PostgREST RPC endpoints)
-- ============================================================================

-- Search climbs by name (fuzzy match)
CREATE OR REPLACE FUNCTION search_climbs(
    p_query TEXT,
    p_limit INT DEFAULT 50
) RETURNS TABLE (
    id UUID,
    name TEXT,
    grade_yds TEXT,
    grade_vscale TEXT,
    area_id UUID,
    area_name TEXT,
    path_tokens TEXT[],
    similarity REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.grade_yds,
        c.grade_vscale,
        c.area_id,
        a.name AS area_name,
        a.path_tokens,
        similarity(c.name, p_query) AS similarity
    FROM climbs c
    JOIN areas a ON c.area_id = a.id
    WHERE c.deleted_at IS NULL
    AND a.deleted_at IS NULL
    AND c.name % p_query  -- trigram similarity
    ORDER BY similarity(c.name, p_query) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Search areas by name (fuzzy match)
CREATE OR REPLACE FUNCTION search_areas(
    p_query TEXT,
    p_limit INT DEFAULT 50
) RETURNS TABLE (
    id UUID,
    name TEXT,
    path_tokens TEXT[],
    is_leaf BOOLEAN,
    total_climbs INT,
    similarity REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.id,
        a.name,
        a.path_tokens,
        a.is_leaf,
        a.total_climbs,
        similarity(a.name, p_query) AS similarity
    FROM areas a
    WHERE a.deleted_at IS NULL
    AND a.name % p_query
    ORDER BY similarity(a.name, p_query) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get area with children and climbs (single query for UI)
CREATE OR REPLACE FUNCTION get_area_details(p_area_id UUID)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_build_object(
        'area', row_to_json(a),
        'children', (
            SELECT COALESCE(json_agg(row_to_json(c) ORDER BY c.left_right_index, c.name), '[]'::JSON)
            FROM areas c
            WHERE c.parent_id = p_area_id AND c.deleted_at IS NULL
        ),
        'climbs', (
            SELECT COALESCE(json_agg(row_to_json(cl) ORDER BY cl.left_right_index, cl.name), '[]'::JSON)
            FROM climbs cl
            WHERE cl.area_id = p_area_id AND cl.deleted_at IS NULL
        ),
        'ancestors', (
            SELECT COALESCE(json_agg(json_build_object('id', anc.id, 'name', anc.name) ORDER BY nlevel(anc.path)), '[]'::JSON)
            FROM areas anc
            WHERE a.path <@ anc.path AND anc.id != a.id AND anc.deleted_at IS NULL
        )
    ) INTO v_result
    FROM areas a
    WHERE a.id = p_area_id AND a.deleted_at IS NULL;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- ROW LEVEL SECURITY (PostgREST auth)
-- ============================================================================

-- Enable RLS on all tables
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

-- Create roles for PostgREST
-- Note: Run these as superuser, not in the schema file typically
-- CREATE ROLE anon NOLOGIN;
-- CREATE ROLE authenticated NOLOGIN;
-- CREATE ROLE editor NOLOGIN;
-- GRANT anon TO authenticator;
-- GRANT authenticated TO authenticator;
-- GRANT editor TO authenticator;

-- Policies: Anonymous read access
CREATE POLICY "anon_read_areas" ON areas FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "anon_read_climbs" ON climbs FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "anon_read_pitches" ON pitches FOR SELECT USING (true);
CREATE POLICY "anon_read_media" ON media FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "anon_read_tags" ON entity_tags FOR SELECT USING (true);
CREATE POLICY "anon_read_ticks" ON ticks FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "anon_read_orgs" ON organizations FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "anon_read_org_areas" ON organization_areas FOR SELECT USING (true);
CREATE POLICY "anon_read_history" ON history FOR SELECT USING (true);
CREATE POLICY "anon_read_users" ON users FOR SELECT USING (deleted_at IS NULL);

-- Policies: Authenticated users can manage their own data
CREATE POLICY "users_manage_own" ON users
    FOR ALL
    USING (id = current_user_id())
    WITH CHECK (id = current_user_id());

CREATE POLICY "users_manage_own_ticks" ON ticks
    FOR ALL
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

CREATE POLICY "users_manage_own_media" ON media
    FOR ALL
    USING (user_id = current_user_id())
    WITH CHECK (user_id = current_user_id());

-- Policies: Editors can modify content
-- Note: These would check is_editor flag or use a role
CREATE POLICY "editors_manage_areas" ON areas
    FOR ALL
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = current_user_id() AND is_editor = true)
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = current_user_id() AND is_editor = true)
    );

CREATE POLICY "editors_manage_climbs" ON climbs
    FOR ALL
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = current_user_id() AND is_editor = true)
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = current_user_id() AND is_editor = true)
    );

CREATE POLICY "editors_manage_orgs" ON organizations
    FOR ALL
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = current_user_id() AND is_admin = true)
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = current_user_id() AND is_admin = true)
    );

-- ============================================================================
-- GRANTS (for PostgREST roles)
-- ============================================================================

-- These would be run after creating the roles
-- GRANT USAGE ON SCHEMA public TO anon, authenticated, editor;

-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO editor;

-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, editor;

-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, editor;
