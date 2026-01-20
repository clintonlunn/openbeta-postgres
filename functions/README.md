# PostgREST Functions

This directory contains all SQL functions that become RPC endpoints via PostgREST.

## Why Functions?

PostgREST automatically generates CRUD endpoints for tables, but sometimes you need:
- **Search** with partial matching and deduplication
- **Aggregations** that combine data from multiple tables
- **Complex logic** that's better expressed in SQL

## Function Index

### Search Functions (`search/`)

| Function | Endpoint | Description |
|----------|----------|-------------|
| `search_climbs` | `POST /rpc/search_climbs` | Search climbs by name with grade/type filters |
| `search_areas` | `POST /rpc/search_areas` | Search areas by name, returns hierarchy |

### Stats Functions (`stats/`)

| Function | Endpoint | Description |
|----------|----------|-------------|
| `area_stats` | `POST /rpc/area_stats` | Get climb counts, grade distribution for an area |
| `user_stats` | `POST /rpc/user_stats` | Get tick counts, hardest sends for a user |

## Adding a New Function

1. Create a `.sql` file in the appropriate subdirectory
2. Use the header template (see `search/search_climbs.sql` for example)
3. Add `COMMENT ON FUNCTION` for OpenAPI docs
4. Update this README
5. Test locally before submitting PR

## Function Design Patterns

### Search Functions (for UI autocomplete)

```sql
CREATE FUNCTION search_foo(
    search_term TEXT DEFAULT NULL,  -- Partial match for dropdown
    search_key TEXT DEFAULT NULL    -- Exact match for selection
)
RETURNS TABLE (...) AS $$
BEGIN
    IF search_key IS NOT NULL THEN
        -- Return exact match with full details
        RETURN QUERY SELECT ... WHERE name = search_key;
    ELSE
        -- Return deduplicated partial matches
        RETURN QUERY SELECT DISTINCT ON (...) ... WHERE name ILIKE search_term LIMIT 50;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;
```

This pattern supports:
- Fast autocomplete (partial match, no geometry, limited results)
- Detail fetch on selection (exact match, full data)

### Aggregation Functions

```sql
CREATE FUNCTION area_stats(area_uuid UUID)
RETURNS TABLE (...) AS $$
    SELECT
        COUNT(*) as total_climbs,
        COUNT(*) FILTER (WHERE is_sport) as sport_count,
        ...
    FROM climbs
    WHERE area_id = area_uuid;
$$ LANGUAGE sql STABLE;
```

## Testing

Each function should have tests in `/tests/`. Use pgTAP or simple assertion queries:

```sql
-- Test search_climbs returns results
DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM search_climbs('%crack%')) > 0,
        'search_climbs should return results for "crack"';
END $$;
```

## Viewing Function Source

If you have database access:

```sql
-- List all functions
\df

-- View function source
\sf search_climbs

-- View function with docs
\df+ search_climbs
```

Without database access, all source is in this directory!
