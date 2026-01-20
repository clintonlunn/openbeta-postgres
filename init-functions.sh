#!/bin/bash
# Load all SQL functions on database initialization

set -e

echo "Loading SQL functions..."

# Find and execute all .sql files in the functions directory
find /docker-entrypoint-initdb.d/functions -name "*.sql" -type f | sort | while read -r file; do
    echo "  Loading: $file"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$file"
done

echo "Functions loaded successfully!"
