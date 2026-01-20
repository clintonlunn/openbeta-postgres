# OpenBeta PostgreSQL

A PostgreSQL + PostgREST backend for OpenBeta climbing data. This is an alternative to the MongoDB + GraphQL architecture, designed for easier contributions and simpler deployments.

## Why PostgreSQL + PostgREST?

| Aspect | MongoDB + GraphQL | PostgreSQL + PostgREST |
|--------|-------------------|------------------------|
| API Generation | Manual resolvers | Automatic from schema |
| Learning Curve | GraphQL + Mongoose | Just SQL |
| Contributions | High barrier | Low barrier |
| Schema Changes | 3 places to update | 1 SQL file |
| Query Language | GraphQL DSL | REST + SQL |

**For FOSS projects**, PostgREST dramatically lowers the contribution barrier:
- Contributors only need SQL knowledge
- All logic is in version-controlled `.sql` files
- No ORM abstractions to learn
- Database changes = instant API changes

## Quick Start

```bash
# Start everything
docker-compose up -d

# API is at http://localhost:3002
# Swagger UI at http://localhost:3003

# Connect to database
make psql

# View available endpoints
curl http://localhost:3002/
```

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │────▶│  PostgREST  │────▶│  PostgreSQL │
│  (Browser)  │     │   (REST)    │     │  (Database) │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                    Auto-generates
                    API from schema
```

- **Tables** → CRUD endpoints (`GET /climbs`, `POST /climbs`, etc.)
- **Views** → Read-only endpoints
- **Functions** → RPC endpoints (`POST /rpc/search_climbs`)

## Project Structure

```
openbeta-postgres/
├── schema.sql              # Tables, indexes, views
├── seed.sql                # Sample data
├── functions/              # SQL functions → RPC endpoints
│   ├── search/
│   │   └── search_climbs.sql
│   └── README.md
├── tests/                  # pgTAP tests
├── docs/                   # Generated API docs
├── docker-compose.yml
├── Makefile
├── CONTRIBUTING.md         # How to contribute
└── README.md
```

## API Examples

### List climbs
```bash
curl "http://localhost:3002/climbs?limit=10"
```

### Filter by grade
```bash
curl "http://localhost:3002/climbs?grade_yds=eq.5.10a"
```

### Search climbs (RPC function)
```bash
curl -X POST "http://localhost:3002/rpc/search_climbs" \
  -H "Content-Type: application/json" \
  -d '{"search_term": "%crack%"}'
```

### Get area with children
```bash
curl "http://localhost:3002/areas?parent_id=eq.{uuid}&select=*,climbs(*)"
```

## Development

```bash
# Start services
make up

# Load/reload functions after editing
make load-functions

# Run tests
make test

# View all commands
make help
```

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for:
- How to add new functions
- Function documentation standards
- Testing guidelines
- Why we keep SQL in version control

## Data Model

### Core Tables
- `areas` - Hierarchical climbing areas (uses ltree)
- `climbs` - Individual routes with grades
- `pitches` - Multi-pitch route segments
- `users` - User accounts
- `ticks` - User climbing logs
- `media` - Photos and images
- `organizations` - Local climbing orgs

### Key Features
- **Hierarchical areas** via PostgreSQL ltree extension
- **Multiple grade systems** (YDS, V-scale, French, Font, etc.)
- **Edit history** tracking all changes
- **Flexible media tagging** with topo annotations

## License

[Same as OpenBeta]
