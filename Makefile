# OpenBeta PostgreSQL Development

.PHONY: up down logs psql reset test help api-test

# =============================================================================
# DOCKER COMMANDS
# =============================================================================

# Start all services
up:
	docker-compose up -d
	@echo ""
	@echo "Services started:"
	@echo "  PostgreSQL:  localhost:5432"
	@echo "  PostgREST:   http://localhost:3002"
	@echo "  Swagger UI:  http://localhost:3003"
	@echo ""

# Stop all services
down:
	docker-compose down

# View logs (follow mode)
logs:
	docker-compose logs -f

# View logs for specific service
logs-db:
	docker-compose logs -f db

logs-api:
	docker-compose logs -f postgrest

# =============================================================================
# DATABASE COMMANDS
# =============================================================================

# Connect to database via psql
psql:
	docker-compose exec db psql -U postgres -d openbeta

# Reset database (WARNING: destroys all data)
reset:
	docker-compose down -v
	docker-compose up -d
	@echo "Database reset complete. Waiting for services..."
	@sleep 5
	@echo "Ready!"

# Reload schema without losing volume (useful for schema iteration)
reload-schema:
	docker-compose exec -T db psql -U postgres -d openbeta -f /workspace/schema-v2.sql
	docker-compose exec -T db psql -U postgres -d openbeta -f /workspace/seed-v2.sql
	@echo "Schema and seed data reloaded."

# =============================================================================
# API TESTING
# =============================================================================

# Test basic API endpoints
api-test:
	@echo "Testing PostgREST API..."
	@echo ""
	@echo "=== Areas (countries) ==="
	@curl -s "http://localhost:3002/areas_active?parent_id=is.null" | head -c 500
	@echo ""
	@echo ""
	@echo "=== Search climbs ==="
	@curl -s "http://localhost:3002/rpc/search_climbs" \
		-H "Content-Type: application/json" \
		-d '{"p_query": "nose", "p_limit": 5}'
	@echo ""
	@echo ""
	@echo "=== Area details ==="
	@curl -s "http://localhost:3002/rpc/get_area_details" \
		-H "Content-Type: application/json" \
		-d '{"p_area_id": "b0000000-0000-0000-0003-000000000001"}'
	@echo ""

# Test specific area by name
test-area:
	@curl -s "http://localhost:3002/areas_active?name=ilike.*$(name)*" | jq

# Test specific climb by name
test-climb:
	@curl -s "http://localhost:3002/climbs_active?name=ilike.*$(name)*" | jq

# =============================================================================
# DATA EXPLORATION
# =============================================================================

# Show all areas as tree
tree:
	@docker-compose exec db psql -U postgres -d openbeta -c "\
		SELECT \
			repeat('  ', nlevel(path)-1) || name as area, \
			total_climbs, \
			is_leaf \
		FROM areas \
		WHERE deleted_at IS NULL \
		ORDER BY path;"

# Show all climbs
climbs:
	@docker-compose exec db psql -U postgres -d openbeta -c "\
		SELECT \
			c.name, \
			COALESCE(c.grade_yds, c.grade_vscale, c.grade_french, c.grade_font) as grade, \
			a.name as area \
		FROM climbs c \
		JOIN areas a ON c.area_id = a.id \
		WHERE c.deleted_at IS NULL \
		ORDER BY a.path, c.name \
		LIMIT 50;"

# Show history log
history:
	@docker-compose exec db psql -U postgres -d openbeta -c "\
		SELECT \
			table_name, \
			operation, \
			changed_at, \
			record_id \
		FROM history \
		ORDER BY changed_at DESC \
		LIMIT 20;"

# Show users
users:
	@docker-compose exec db psql -U postgres -d openbeta -c "\
		SELECT username, display_name, is_editor, is_admin \
		FROM users \
		WHERE deleted_at IS NULL;"

# =============================================================================
# STATS
# =============================================================================

# Show database stats
stats:
	@docker-compose exec db psql -U postgres -d openbeta -c "\
		SELECT 'areas' as table_name, COUNT(*) as count FROM areas WHERE deleted_at IS NULL \
		UNION ALL \
		SELECT 'climbs', COUNT(*) FROM climbs WHERE deleted_at IS NULL \
		UNION ALL \
		SELECT 'users', COUNT(*) FROM users WHERE deleted_at IS NULL \
		UNION ALL \
		SELECT 'ticks', COUNT(*) FROM ticks WHERE deleted_at IS NULL \
		UNION ALL \
		SELECT 'media', COUNT(*) FROM media WHERE deleted_at IS NULL \
		UNION ALL \
		SELECT 'history', COUNT(*) FROM history;"

# =============================================================================
# HELP
# =============================================================================

help:
	@echo "OpenBeta PostgreSQL Development Commands"
	@echo ""
	@echo "Docker:"
	@echo "  make up              - Start all services"
	@echo "  make down            - Stop all services"
	@echo "  make logs            - View all logs"
	@echo "  make logs-db         - View database logs"
	@echo "  make logs-api        - View PostgREST logs"
	@echo ""
	@echo "Database:"
	@echo "  make psql            - Connect to database"
	@echo "  make reset           - Reset database (destroys data)"
	@echo "  make reload-schema   - Reload schema without losing volume"
	@echo ""
	@echo "Testing:"
	@echo "  make api-test        - Test basic API endpoints"
	@echo "  make test-area name=yosemite  - Find area by name"
	@echo "  make test-climb name=nose     - Find climb by name"
	@echo ""
	@echo "Exploration:"
	@echo "  make tree            - Show area hierarchy"
	@echo "  make climbs          - List climbs"
	@echo "  make users           - List users"
	@echo "  make history         - Show recent changes"
	@echo "  make stats           - Show table counts"
	@echo ""
	@echo "URLs:"
	@echo "  API:     http://localhost:3002"
	@echo "  Swagger: http://localhost:3003"
