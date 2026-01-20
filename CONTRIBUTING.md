# Contributing to OpenBeta PostgreSQL

This project uses **PostgREST** to auto-generate a REST API from the PostgreSQL schema. This means:

- Tables → CRUD endpoints (automatic)
- Views → Read-only endpoints (automatic)
- Functions → RPC endpoints (automatic)

## Project Structure

```
openbeta-postgres/
├── schema.sql              # Core tables, indexes, views
├── seed.sql                # Sample data for development
├── functions/              # SQL functions (RPC endpoints)
│   ├── search/
│   │   ├── search_climbs.sql
│   │   ├── search_areas.sql
│   │   └── README.md       # Documents all search functions
│   ├── stats/
│   │   ├── area_stats.sql
│   │   └── user_stats.sql
│   └── README.md           # Index of all functions
├── migrations/             # Schema changes (numbered)
│   ├── 001_initial.sql
│   ├── 002_add_grades.sql
│   └── README.md
├── tests/                  # pgTAP tests
│   └── test_search.sql
├── docs/
│   ├── API.md              # Generated API documentation
│   └── SCHEMA.md           # ERD and table descriptions
├── docker-compose.yml
├── Makefile                # Common tasks
└── CONTRIBUTING.md
```

## How PostgREST Works

### Tables = CRUD Endpoints

```sql
-- This table in schema.sql:
CREATE TABLE climbs (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    grade_yds TEXT
);
```

Automatically becomes:
- `GET /climbs` - List all
- `GET /climbs?id=eq.xxx` - Get one
- `GET /climbs?grade_yds=eq.5.10a` - Filter
- `POST /climbs` - Create
- `PATCH /climbs?id=eq.xxx` - Update
- `DELETE /climbs?id=eq.xxx` - Delete

### Functions = RPC Endpoints

```sql
-- This function in functions/search/search_climbs.sql:
CREATE FUNCTION search_climbs(search_term TEXT)
RETURNS TABLE (id UUID, name TEXT, grade_yds TEXT) AS $$
  SELECT id, name, grade_yds
  FROM climbs
  WHERE name ILIKE '%' || search_term || '%'
  LIMIT 50;
$$ LANGUAGE sql STABLE;
```

Automatically becomes:
- `POST /rpc/search_climbs` with `{"search_term": "finger crack"}`

## Adding a New Function

1. **Create the SQL file** in `functions/<category>/`
2. **Add header documentation**:
   ```sql
   -- Function: search_climbs
   -- Purpose: Full-text search on climb names with optional filters
   --
   -- Parameters:
   --   search_term (TEXT) - Partial name match (required)
   --   grade_min (TEXT) - Minimum YDS grade (optional)
   --   grade_max (TEXT) - Maximum YDS grade (optional)
   --
   -- Returns: Table of matching climbs with area info
   --
   -- Example:
   --   POST /rpc/search_climbs
   --   {"search_term": "crack", "grade_min": "5.9"}
   --
   -- Author: @username
   -- Date: 2024-01-19
   ```

3. **Add PostgreSQL COMMENT** (shows in OpenAPI docs):
   ```sql
   COMMENT ON FUNCTION search_climbs IS
     'Search climbs by name. Returns id, name, grade, and area info.';
   ```

4. **Add to init script** or run migration
5. **Update `functions/README.md`** with the new function
6. **Add tests** in `tests/`

## Local Development

```bash
# Start the database and API
docker-compose up -d

# View API docs
open http://localhost:3002/

# Apply schema changes
docker-compose exec db psql -U postgres -d openbeta -f /path/to/file.sql

# Run tests
docker-compose exec db psql -U postgres -d openbeta -f tests/test_search.sql
```

## Understanding Existing Functions

All functions are documented in `functions/README.md` with:
- Purpose
- Parameters
- Return type
- Example API calls

You can also explore via the OpenAPI spec at `http://localhost:3002/` or query the database directly:

```sql
-- List all functions
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public' AND routine_type = 'FUNCTION';

-- Get function details
\df+ function_name
```

## Why This Structure?

PostgREST is powerful but can be a "black box" if functions only live in the database. By keeping all SQL in version-controlled files with documentation:

1. **Contributors can read the code** without database access
2. **Changes are reviewable** in PRs
3. **Documentation stays in sync** with implementation
4. **New contributors understand** what each function does
5. **Testing is possible** via pgTAP

## Questions?

Open an issue or join the Discord!
