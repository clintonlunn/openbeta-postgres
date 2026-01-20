-- =============================================================================
-- Function: search_climbs
-- =============================================================================
-- Purpose: Search climbs by name with optional grade and type filters.
--          Returns deduplicated results suitable for autocomplete/search UI.
--
-- Parameters:
--   search_term (TEXT)    - Partial name match, uses ILIKE (required)
--   search_key (TEXT)     - Exact name match for fetching full details (optional)
--   grade_min (TEXT)      - Minimum YDS grade filter (optional)
--   grade_max (TEXT)      - Maximum YDS grade filter (optional)
--   climb_type (TEXT)     - Filter by type: sport, trad, boulder (optional)
--
-- Returns: Table of matching climbs with area context
--
-- Behavior:
--   - If search_key is provided: returns exact match with full geometry
--   - If search_term is provided: returns partial matches for dropdown
--
-- Example API calls:
--   -- Autocomplete search (dropdown)
--   POST /rpc/search_climbs
--   {"search_term": "%crack%"}
--
--   -- Get specific climb (on selection)
--   POST /rpc/search_climbs
--   {"search_key": "Midnight Lightning"}
--
--   -- Filtered search
--   POST /rpc/search_climbs
--   {"search_term": "%crack%", "grade_min": "5.10a", "climb_type": "trad"}
--
-- Author: @yourname
-- Created: 2024-01-19
-- =============================================================================

CREATE OR REPLACE FUNCTION search_climbs(
    search_term TEXT DEFAULT NULL,
    search_key TEXT DEFAULT NULL,
    grade_min TEXT DEFAULT NULL,
    grade_max TEXT DEFAULT NULL,
    climb_type TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    grade_yds TEXT,
    area_name TEXT,
    area_id UUID,
    lat FLOAT,
    lng FLOAT
) AS $$
BEGIN
    -- Mode 1: Exact match (for fetching selected item)
    IF search_key IS NOT NULL THEN
        RETURN QUERY
        SELECT
            c.id,
            c.name,
            c.grade_yds,
            a.name AS area_name,
            c.area_id,
            c.lat,
            c.lng
        FROM climbs c
        LEFT JOIN areas a ON c.area_id = a.id
        WHERE c.name = search_key;
        RETURN;
    END IF;

    -- Mode 2: Partial match (for search dropdown)
    IF search_term IS NOT NULL THEN
        RETURN QUERY
        SELECT DISTINCT ON (c.name, c.grade_yds)
            c.id,
            c.name,
            c.grade_yds,
            a.name AS area_name,
            c.area_id,
            c.lat,
            c.lng
        FROM climbs c
        LEFT JOIN areas a ON c.area_id = a.id
        WHERE
            c.name ILIKE search_term
            -- Optional filters
            AND (grade_min IS NULL OR c.grade_yds >= grade_min)
            AND (grade_max IS NULL OR c.grade_yds <= grade_max)
            AND (climb_type IS NULL OR
                (climb_type = 'sport' AND c.is_sport = TRUE) OR
                (climb_type = 'trad' AND c.is_trad = TRUE) OR
                (climb_type = 'boulder' AND c.is_boulder = TRUE)
            )
        ORDER BY c.name, c.grade_yds
        LIMIT 50;
        RETURN;
    END IF;

    -- No search criteria provided
    RETURN;
END;
$$ LANGUAGE plpgsql STABLE;

-- Documentation for OpenAPI/Swagger
COMMENT ON FUNCTION search_climbs IS
    'Search climbs by name. Use search_term for autocomplete, search_key for exact match.';

-- Grant access to anonymous role (adjust role name as needed)
-- GRANT EXECUTE ON FUNCTION search_climbs TO web_anon;
