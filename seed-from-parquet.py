#!/usr/bin/env python3
"""
Seed PostgreSQL database from OpenBeta parquet export.
Builds area hierarchy from climb path tokens and inserts climbs.
"""

import duckdb
import psycopg2
from psycopg2.extras import execute_values
import uuid
import re
import sys
import os
import pandas as pd
from pathlib import Path

# Config - use environment variables if available, else defaults for local dev
PARQUET_FILE = Path(os.environ.get("PARQUET_FILE",
    Path(__file__).parent.parent / "parquet-exporter" / "openbeta-climbs.parquet"))

DB_CONFIG = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": int(os.environ.get("PGPORT", 5432)),
    "database": os.environ.get("PGDATABASE", "openbeta"),
    "user": os.environ.get("PGUSER", "postgres"),
    "password": os.environ.get("PGPASSWORD", "postgres")
}

# Supabase requires SSL
if "supabase" in os.environ.get("PGHOST", ""):
    DB_CONFIG["sslmode"] = "require"

BATCH_SIZE = 10000

def log(msg):
    """Print with immediate flush"""
    print(msg, flush=True)

def slugify(text):
    """Convert text to ltree-safe label"""
    if not text:
        return None
    slug = re.sub(r'[^a-zA-Z0-9]+', '_', text.lower())
    slug = slug.strip('_')
    if slug and slug[0].isdigit():
        slug = 'n' + slug
    return slug or None

def build_area_hierarchy(climbs_df):
    """Build area hierarchy from climb location data."""
    areas = {}
    total = len(climbs_df)

    for idx, row in enumerate(climbs_df.itertuples()):
        if idx % 50000 == 0:
            log(f"  Processing climb {idx:,}/{total:,}...")

        tokens = []
        for level in ['country', 'state_province', 'region', 'area', 'crag']:
            val = getattr(row, level, None)
            if val and not pd.isna(val) and str(val).strip():
                tokens.append(str(val).strip())
            else:
                break

        if not tokens:
            continue

        for i in range(1, len(tokens) + 1):
            path_tuple = tuple(tokens[:i])

            if path_tuple not in areas:
                name = tokens[i-1]
                parent_tuple = tuple(tokens[:i-1]) if i > 1 else None
                ltree_path = '.'.join(slugify(t) for t in tokens[:i])

                areas[path_tuple] = {
                    'id': str(uuid.uuid4()),
                    'name': name,
                    'path_tuple': path_tuple,
                    'parent_tuple': parent_tuple,
                    'ltree_path': ltree_path,
                    'path_tokens': list(path_tuple),
                    'is_leaf': (i == len(tokens)),
                    'lat': None,
                    'lng': None,
                    'climb_count': 0
                }

            if i == len(tokens):
                areas[path_tuple]['is_leaf'] = True
                areas[path_tuple]['climb_count'] += 1
                if areas[path_tuple]['lat'] is None:
                    lat = getattr(row, 'latitude', None)
                    if lat and not pd.isna(lat):
                        areas[path_tuple]['lat'] = lat
                        areas[path_tuple]['lng'] = getattr(row, 'longitude', None)

    return areas

def main():
    log("=" * 60)
    log("OpenBeta Postgres Seeder")
    log("=" * 60)

    log(f"\nLoading {PARQUET_FILE}...")
    con = duckdb.connect()
    df = con.execute(f"SELECT * FROM '{PARQUET_FILE}'").fetchdf()
    log(f"Loaded {len(df):,} climbs")

    log("\nBuilding area hierarchy...")
    areas = build_area_hierarchy(df)
    log(f"Found {len(areas):,} unique areas")

    log("Resolving parent relationships...")
    for area in areas.values():
        if area['parent_tuple']:
            parent = areas.get(area['parent_tuple'])
            area['parent_id'] = parent['id'] if parent else None
        else:
            area['parent_id'] = None

    log(f"\nConnecting to PostgreSQL...")
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    log("Clearing existing data...")
    cur.execute("TRUNCATE climbs, areas, pitches, ticks, media, entity_tags, organizations, organization_areas, history CASCADE")
    conn.commit()

    # Disable history triggers during bulk import
    log("Disabling history triggers...")
    cur.execute("ALTER TABLE areas DISABLE TRIGGER areas_history_trigger")
    cur.execute("ALTER TABLE climbs DISABLE TRIGGER climbs_history_trigger")
    cur.execute("ALTER TABLE climbs DISABLE TRIGGER climbs_stats_trigger")
    conn.commit()

    log("Inserting areas...")
    sorted_areas = sorted(areas.values(), key=lambda a: len(a['path_tuple']))

    area_values = [
        (
            a['id'], a['parent_id'], a['name'], a['ltree_path'],
            a['path_tokens'], a['lat'], a['lng'], a['is_leaf'], a['climb_count']
        )
        for a in sorted_areas
    ]

    execute_values(
        cur,
        """INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_leaf, total_climbs)
           VALUES %s""",
        area_values,
        template="(%s, %s, %s, %s::ltree, %s, %s, %s, %s, %s)"
    )
    conn.commit()
    log(f"Inserted {len(area_values):,} areas")

    area_lookup = {a['path_tuple']: a['id'] for a in areas.values()}

    log("Building climb data...")
    climb_values = []
    skipped = 0
    total = len(df)

    for idx, row in enumerate(df.itertuples()):
        if idx % 50000 == 0:
            log(f"  Processing climb {idx:,}/{total:,}...")

        tokens = []
        for level in ['country', 'state_province', 'region', 'area', 'crag']:
            val = getattr(row, level, None)
            if val and not pd.isna(val) and str(val).strip():
                tokens.append(str(val).strip())
            else:
                break

        if not tokens:
            skipped += 1
            continue

        path_tuple = tuple(tokens)
        area_id = area_lookup.get(path_tuple)

        if not area_id:
            skipped += 1
            continue

        climb_values.append((
            str(row.climb_id),
            area_id,
            row.climb_name,
            row.grade_yds if not pd.isna(row.grade_yds) else None,
            row.grade_vscale if not pd.isna(row.grade_vscale) else None,
            row.grade_french if not pd.isna(row.grade_french) else None,
            bool(row.is_trad) if not pd.isna(row.is_trad) else False,
            bool(row.is_sport) if not pd.isna(row.is_sport) else False,
            bool(row.is_boulder) if not pd.isna(row.is_boulder) else False,
            bool(row.is_alpine) if not pd.isna(row.is_alpine) else False,
            bool(row.is_top_rope) if not pd.isna(row.is_top_rope) else False,
            int(row.length_meters) if not pd.isna(row.length_meters) and row.length_meters > 0 else None,
            int(row.bolts_count) if not pd.isna(row.bolts_count) and row.bolts_count > 0 else None,
            row.first_ascent if not pd.isna(row.first_ascent) else None,
            row.safety if not pd.isna(row.safety) and row.safety != 'None' else 'UNSPECIFIED',
            row.latitude if not pd.isna(row.latitude) else None,
            row.longitude if not pd.isna(row.longitude) else None,
            row.description if not pd.isna(row.description) else None
        ))

    log(f"Inserting {len(climb_values):,} climbs in batches of {BATCH_SIZE}...")
    inserted = 0
    for i in range(0, len(climb_values), BATCH_SIZE):
        batch = climb_values[i:i + BATCH_SIZE]
        execute_values(
            cur,
            """INSERT INTO climbs (
                id, area_id, name,
                grade_yds, grade_vscale, grade_french,
                is_trad, is_sport, is_boulder, is_alpine, is_tr,
                length_meters, bolts_count, fa, safety,
                lat, lng, description
            ) VALUES %s
            ON CONFLICT (id) DO NOTHING""",
            batch,
            template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::safety_rating, %s, %s, %s)"
        )
        conn.commit()
        inserted += len(batch)
        log(f"  Inserted {inserted:,}/{len(climb_values):,} climbs...")

    log(f"Inserted {len(climb_values):,} climbs ({skipped} skipped)")

    # Re-enable triggers for normal operation
    log("Re-enabling triggers...")
    cur.execute("ALTER TABLE areas ENABLE TRIGGER areas_history_trigger")
    cur.execute("ALTER TABLE climbs ENABLE TRIGGER climbs_history_trigger")
    cur.execute("ALTER TABLE climbs ENABLE TRIGGER climbs_stats_trigger")
    conn.commit()

    cur.execute("SELECT COUNT(*) FROM areas")
    area_count = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM climbs")
    climb_count = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM areas WHERE is_leaf = true")
    leaf_count = cur.fetchone()[0]

    log(f"\n{'=' * 60}")
    log(f"Database seeded successfully!")
    log(f"  Areas: {area_count:,} ({leaf_count:,} leaf nodes)")
    log(f"  Climbs: {climb_count:,}")
    log(f"{'=' * 60}")

    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
