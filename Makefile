# OpenBeta PostgreSQL Development

.PHONY: up down logs psql reset test help api-test \
        supabase-seed supabase-reset supabase-schema supabase-rls \
        deploy-ui full-reset infra-plan infra-apply

# Load .env file if it exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

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

# =============================================================================
# SUPABASE COMMANDS (requires .env with PGHOST, PGUSER, PGPASSWORD, etc.)
# =============================================================================

# Connection string for Supabase
SUPABASE_CONN := postgresql://$(PGUSER):$(PGPASSWORD)@$(PGHOST):$(PGPORT)/$(PGDATABASE)?sslmode=require

# Check if Supabase env vars are set
check-supabase-env:
	@if [ -z "$(PGHOST)" ] || [ -z "$(PGPASSWORD)" ]; then \
		echo "Error: Missing Supabase env vars. Create .env file with:"; \
		echo "  PGHOST=aws-0-us-west-2.pooler.supabase.com"; \
		echo "  PGPORT=5432"; \
		echo "  PGDATABASE=postgres"; \
		echo "  PGUSER=postgres.your-project-ref"; \
		echo "  PGPASSWORD=your-password"; \
		exit 1; \
	fi

# Seed Supabase from parquet file
supabase-seed: check-supabase-env
	@echo "Downloading latest parquet file..."
	curl -sL -o openbeta-climbs.parquet \
		"https://github.com/OpenBeta/parquet-exporter/releases/latest/download/openbeta-climbs.parquet"
	@echo "Seeding Supabase..."
	PARQUET_FILE=openbeta-climbs.parquet python3 seed.py
	@echo "Done! Cleaning up..."
	rm -f openbeta-climbs.parquet

# Apply schema to Supabase (simplified 4-table schema)
supabase-schema: check-supabase-env
	@echo "Applying simplified schema to Supabase..."
	psql "$(SUPABASE_CONN)" -f schema.sql
	@echo "Schema applied."

# Full Supabase reset (schema + seed) - RLS is included in schema-simple.sql
supabase-reset: check-supabase-env supabase-schema supabase-seed
	@echo ""
	@echo "=========================================="
	@echo "Supabase fully reset!"
	@echo "=========================================="

# Connect to Supabase via psql
supabase-psql: check-supabase-env
	psql "$(SUPABASE_CONN)"

# Show Supabase stats
supabase-stats: check-supabase-env
	@psql "$(SUPABASE_CONN)" -c "\
		SELECT 'areas' as table_name, COUNT(*) as count FROM areas \
		UNION ALL \
		SELECT 'climbs', COUNT(*) FROM climbs \
		UNION ALL \
		SELECT 'users', COUNT(*) FROM users \
		UNION ALL \
		SELECT 'ticks', COUNT(*) FROM ticks;"

# =============================================================================
# DEPLOYMENT COMMANDS
# =============================================================================

# Build and deploy UI to Cloudflare Workers
deploy-ui:
	@echo "Building UI..."
	cd ui/tanstack && npm run build
	@echo "Deploying to Cloudflare Workers..."
	cd ui/tanstack && npx wrangler deploy
	@echo "Deployed!"

# =============================================================================
# INFRASTRUCTURE (OpenTofu)
# =============================================================================

# Plan infrastructure changes
infra-plan:
	cd infra && ~/.local/bin/tofu plan

# Apply infrastructure changes
infra-apply:
	cd infra && ~/.local/bin/tofu apply

# Initialize infrastructure
infra-init:
	cd infra && ~/.local/bin/tofu init

# Import existing Supabase project
infra-import:
	@if [ -z "$(PROJECT_REF)" ]; then \
		echo "Usage: make infra-import PROJECT_REF=your-project-ref"; \
		exit 1; \
	fi
	cd infra && ~/.local/bin/tofu import supabase_project.main $(PROJECT_REF)

# =============================================================================
# FULL RESET (blow everything away and rebuild)
# =============================================================================

# Quick reset: just reseed existing project
quick-reset: supabase-reset deploy-ui
	@echo ""
	@echo "=========================================="
	@echo "Quick reset complete!"
	@echo "  - Database: reset and seeded"
	@echo "  - UI: rebuilt and deployed"
	@echo "=========================================="

# Full IaC reset: destroy and recreate Supabase project via OpenTofu
full-reset:
	@./scripts/full-iac-reset.sh

# =============================================================================
# HELP
# =============================================================================

help:
	@echo "OpenBeta PostgreSQL Development Commands"
	@echo ""
	@echo "Docker (local dev):"
	@echo "  make up              - Start all services"
	@echo "  make down            - Stop all services"
	@echo "  make logs            - View all logs"
	@echo "  make psql            - Connect to local database"
	@echo "  make reset           - Reset local database"
	@echo ""
	@echo "Supabase (production):"
	@echo "  make supabase-seed   - Seed from parquet"
	@echo "  make supabase-schema - Apply simplified schema (includes RLS)"
	@echo "  make supabase-reset  - Full reset (schema + seed)"
	@echo "  make supabase-psql   - Connect to Supabase"
	@echo "  make supabase-stats  - Show table counts"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-ui       - Build and deploy UI to Cloudflare"
	@echo "  make quick-reset     - Reseed existing project + redeploy UI"
	@echo "  make full-reset      - DESTROY and recreate everything via IaC"
	@echo ""
	@echo "Infrastructure (OpenTofu):"
	@echo "  make infra-init      - Initialize OpenTofu"
	@echo "  make infra-plan      - Plan changes"
	@echo "  make infra-apply     - Apply changes"
	@echo "  make infra-import PROJECT_REF=xxx - Import existing project"
	@echo ""
	@echo "Testing:"
	@echo "  make api-test        - Test local API endpoints"
	@echo "  make stats           - Show local table counts"
	@echo ""
	@echo "Required: Create .env file with Supabase credentials"
	@echo "  See .env.example for template"
