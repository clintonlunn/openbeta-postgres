#!/bin/bash
set -e

# Full IaC Reset Script
# Destroys and recreates everything from scratch using OpenTofu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "OpenBeta Full IaC Reset"
echo "=========================================="
echo ""

# Check for required tools
command -v tofu >/dev/null 2>&1 || command -v ~/.local/bin/tofu >/dev/null 2>&1 || {
    echo "Error: OpenTofu not found. Install with:"
    echo "  curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh"
    exit 1
}
TOFU=$(command -v tofu 2>/dev/null || echo ~/.local/bin/tofu)

command -v psql >/dev/null 2>&1 || {
    echo "Error: psql not found. Install postgresql-client."
    exit 1
}

# Check for terraform.tfvars
if [ ! -f "$ROOT_DIR/infra/terraform.tfvars" ]; then
    echo "Error: infra/terraform.tfvars not found."
    echo "Copy from terraform.tfvars.example and fill in your values."
    exit 1
fi

# Confirm destruction
echo "WARNING: This will DESTROY and RECREATE:"
echo "  - Supabase project (all data will be lost)"
echo "  - Cloudflare Worker deployment"
echo ""
read -p "Type 'yes' to continue: " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1/7: Destroying existing infrastructure..."
cd "$ROOT_DIR/infra"
$TOFU destroy -auto-approve || true

echo ""
echo "Step 2/7: Creating new Supabase project..."
$TOFU apply -auto-approve

echo ""
echo "Step 3/7: Waiting for Supabase project to be ready (~2 min)..."
sleep 120

echo ""
echo "Step 4/7: Getting connection details..."
PROJECT_ID=$($TOFU output -raw supabase_project_id)
SUPABASE_URL=$($TOFU output -raw supabase_api_url)
ANON_KEY=$($TOFU output -raw supabase_anon_key)
POOLER_HOST=$($TOFU output -raw supabase_pooler_host)

# Get password from tfvars (grep it out)
DB_PASSWORD=$(grep 'supabase_database_password' terraform.tfvars | sed 's/.*= *"//' | sed 's/".*//')

# Build connection string
CONN="postgresql://postgres.${PROJECT_ID}:${DB_PASSWORD}@${POOLER_HOST}:5432/postgres?sslmode=require"

echo "  Project ID: $PROJECT_ID"
echo "  API URL: $SUPABASE_URL"

echo ""
echo "Step 5/7: Applying schema and RLS..."
cd "$ROOT_DIR"
psql "$CONN" -f schema-v2.sql
psql "$CONN" -f rls-generic.sql

echo ""
echo "Step 6/7: Seeding database..."
# Download parquet
curl -sL -o openbeta-climbs.parquet \
    "https://github.com/OpenBeta/parquet-exporter/releases/latest/download/openbeta-climbs.parquet"

# Run seed
PGHOST="$POOLER_HOST" \
PGPORT=5432 \
PGDATABASE=postgres \
PGUSER="postgres.${PROJECT_ID}" \
PGPASSWORD="$DB_PASSWORD" \
PARQUET_FILE=openbeta-climbs.parquet \
python3 seed-from-parquet.py

rm -f openbeta-climbs.parquet

echo ""
echo "Step 7/7: Updating UI and deploying..."
# Update UI .env
cat > "$ROOT_DIR/ui/tanstack/.env" << EOF
VITE_SUPABASE_URL=$SUPABASE_URL
VITE_SUPABASE_ANON_KEY=$ANON_KEY
EOF

# Build and deploy
cd "$ROOT_DIR/ui/tanstack"
npm run build
npx wrangler deploy

echo ""
echo "=========================================="
echo "Full IaC Reset Complete!"
echo "=========================================="
echo ""
echo "New Supabase Project:"
echo "  ID:  $PROJECT_ID"
echo "  URL: $SUPABASE_URL"
echo ""
echo "Worker deployed to Cloudflare"
echo ""
echo "Update your root .env with:"
echo "  PGHOST=$POOLER_HOST"
echo "  PGUSER=postgres.${PROJECT_ID}"
echo "  PGPASSWORD=$DB_PASSWORD"
echo ""
