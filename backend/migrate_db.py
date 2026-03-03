"""
migrate_db.py — Production Schema Sync
=======================================
Run this script on the production server to bring the database schema up to date
with the latest model definitions in models.py.

Usage:
    python migrate_db.py

It performs safe, additive-only migrations:
  - Creates any missing tables.
  - Adds any missing columns (with correct types and nullable defaults).
  - Never drops columns or tables (safe for production).
"""

import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text, inspect
import os
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

# ---------------------------------------------------------------------------
# Define the canonical schema derived from models.py
# Format: { table_name: { column_name: (sql_type, default_clause_or_None) } }
# ---------------------------------------------------------------------------

SCHEMA = {
    "user": {
        "id":                          ("SERIAL PRIMARY KEY",  None),
        "uid":                         ("VARCHAR NOT NULL",    None),
        "email":                       ("VARCHAR NOT NULL",    None),
        "name":                        ("VARCHAR",             None),
        "is_admin":                    ("BOOLEAN",             "DEFAULT FALSE"),
        # Contact Info
        "profile_image":               ("VARCHAR",             None),
        "job_title":                   ("VARCHAR",             None),
        "phone_number":                ("VARCHAR",             None),
        "linkedin_url":                ("VARCHAR",             None),
        # Company Info
        "company_name":                ("VARCHAR",             None),
        "company_website":             ("VARCHAR",             None),
        "industry":                    ("VARCHAR",             None),
        "employee_count":              ("VARCHAR",             None),
        "country":                     ("VARCHAR",             None),
        # Use Case
        "project_type":                ("VARCHAR",             None),
        "expected_seats":              ("INTEGER",             None),
        # Settings
        "local_sync_path":             ("VARCHAR",             None),
        "bim_upload_hub_id":           ("VARCHAR",             None),
        "bim_upload_hub_name":         ("VARCHAR",             None),
        "bim_upload_project_id":       ("VARCHAR",             None),
        "bim_upload_project_name":     ("VARCHAR",             None),
        "bim_upload_folder_id":        ("VARCHAR",             None),
        "bim_upload_folder_name":      ("VARCHAR",             None),
        # Billing
        "subscription_plan":           ("VARCHAR",             None),
        "subscription_expiry":         ("TIMESTAMPTZ",         None),
        # Autodesk
        "autodesk_id":                 ("VARCHAR",             None),
        "autodesk_code_verifier":      ("VARCHAR",             None),
        "autodesk_access_token":       ("VARCHAR",             None),
        "autodesk_refresh_token":      ("VARCHAR",             None),
        "autodesk_token_expires":      ("TIMESTAMPTZ",         None),
        "created_at":                  ("TIMESTAMPTZ",         "DEFAULT NOW()"),
    },
    "project": {
        "id":                              ("SERIAL PRIMARY KEY", None),
        "name":                            ("VARCHAR NOT NULL",   None),
        "owner_uid":                       ("VARCHAR",            None),
        "model_filename":                  ("VARCHAR",            None),
        # Unity Metadata
        "loaded_model_offset_position":    ("VARCHAR",            None),
        "loaded_model_offset_rotation":    ("VARCHAR",            None),
        "loaded_model_offset_scale":       ("VARCHAR",            None),
        "vrmenu_model_position":           ("VARCHAR",            None),
        "vrmenu_model_scale":              ("VARCHAR",            None),
        "created_model_center":            ("VARCHAR",            None),
        "show_selection_set_index":        ("VARCHAR",            None),
        "list_of_teleport_locations":      ("VARCHAR",            None),
        "list_of_ar_location_file_path":   ("VARCHAR",            None),
        "list_of_custom_model_data":       ("VARCHAR",            None),
        "list_of_custom_model_xrpath":     ("VARCHAR",            None),
        "arcount_stamp":                   ("VARCHAR",            None),
        "list_of_rules":                   ("VARCHAR",            None),
        "list_of_marker_issue":            ("VARCHAR",            None),
        "list_of_marker_lable":            ("VARCHAR",            None),
        "last_teleported_location":        ("VARCHAR",            None),
        "project_geometry_path":           ("VARCHAR",            None),
        "project_material_path":           ("VARCHAR",            None),
        "project_udata_path":              ("VARCHAR",            None),
        "teleport_last_index":             ("INTEGER",            None),
        "ruler_last_index":                ("INTEGER",            None),
        "marker_issue_last_index":         ("INTEGER",            None),
        "marker_lable_last_index":         ("INTEGER",            None),
        "created_at":                      ("TIMESTAMPTZ",        "DEFAULT NOW()"),
    },
    "issue": {
        "id":            ("SERIAL PRIMARY KEY", None),
        "project_id":    ("INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE", None),
        "author_uid":    ("VARCHAR NOT NULL",   None),
        "title":         ("VARCHAR NOT NULL",   None),
        "description":   ("VARCHAR",            None),
        "status":        ("VARCHAR",            "DEFAULT 'open'"),
        "priority":      ("VARCHAR",            "DEFAULT 'medium'"),
        "x_coord":       ("FLOAT",              None),
        "y_coord":       ("FLOAT",              None),
        "z_coord":       ("FLOAT",              None),
    },
    "documentationtopic": {
        "id":          ("SERIAL PRIMARY KEY", None),
        "parent_id":   ("INTEGER REFERENCES documentationtopic(id) ON DELETE CASCADE", None),
        "title":       ("VARCHAR NOT NULL",   None),
        "icon_name":   ("VARCHAR",            "DEFAULT 'description_outlined'"),
        "order_index": ("INTEGER",            "DEFAULT 0"),
        "created_at":  ("TIMESTAMPTZ",        "DEFAULT NOW()"),
    },
    "documentationsection": {
        "id":           ("SERIAL PRIMARY KEY", None),
        "topic_id":     ("INTEGER NOT NULL REFERENCES documentationtopic(id) ON DELETE CASCADE", None),
        "type":         ("VARCHAR",            "DEFAULT 'text'"),
        "title":        ("VARCHAR",            None),
        "content_text": ("TEXT",               None),
        "media_url":    ("VARCHAR",            None),
        "media_list":   ("TEXT",               None),
        "order_index":  ("INTEGER",            "DEFAULT 0"),
    },
    "pkcestate": {
        "id":             ("SERIAL PRIMARY KEY", None),
        "state":          ("VARCHAR NOT NULL",   None),
        "code_verifier":  ("VARCHAR NOT NULL",   None),
        "linking_uid":    ("VARCHAR",            None),
        "redirect_uri":   ("VARCHAR",            None),
        "custom_token":   ("VARCHAR",            None),
        "expires_at":     ("TIMESTAMPTZ NOT NULL", None),
    },
}

# ---------------------------------------------------------------------------

async def get_existing_tables(conn) -> set:
    res = await conn.execute(text(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = 'public'"
    ))
    return {row[0] for row in res.fetchall()}


async def get_existing_columns(conn, table_name: str) -> set:
    res = await conn.execute(text(
        "SELECT column_name FROM information_schema.columns "
        f"WHERE table_schema = 'public' AND table_name = '{table_name}'"
    ))
    return {row[0] for row in res.fetchall()}


async def create_table(conn, table_name: str, columns: dict):
    """Create a full table from scratch based on the schema definition."""
    col_defs = []
    for col_name, (col_type, default) in columns.items():
        # Skip composite definitions that embed PRIMARY KEY (they go first)
        defn = f'"{col_name}" {col_type}'
        if default:
            defn += f" {default}"
        col_defs.append(defn)
    ddl = f'CREATE TABLE IF NOT EXISTS "{table_name}" ({", ".join(col_defs)})'
    print(f"  Creating table '{table_name}'...")
    await conn.execute(text(ddl))
    print(f"  ✓ Table '{table_name}' created.")


async def sync_table_columns(conn, table_name: str, columns: dict):
    """Add any missing columns to an existing table."""
    existing_cols = await get_existing_columns(conn, table_name)
    for col_name, (col_type, default) in columns.items():
        if col_name in existing_cols:
            continue
        # Primary key columns and complex references can't be added with ALTER easily
        if "PRIMARY KEY" in col_type or "NOT NULL" in col_type and default is None:
            # Try adding as nullable version (strip NOT NULL for safety)
            safe_type = col_type.replace("NOT NULL", "").strip()
            stmt = f'ALTER TABLE "{table_name}" ADD COLUMN IF NOT EXISTS "{col_name}" {safe_type}'
        else:
            stmt = f'ALTER TABLE "{table_name}" ADD COLUMN IF NOT EXISTS "{col_name}" {col_type}'
            if default:
                stmt += f" {default}"
        print(f"  Adding column '{col_name}' to '{table_name}'...")
        try:
            await conn.execute(text(stmt))
            print(f"  ✓ Column '{col_name}' added.")
        except Exception as e:
            print(f"  ⚠ Could not add '{col_name}' to '{table_name}': {e}")


async def migrate():
    if not DATABASE_URL:
        print("❌ Error: DATABASE_URL not found in environment. Check your .env file.")
        return

    print(f"Connecting to database...")
    engine = create_async_engine(DATABASE_URL)

    async with engine.begin() as conn:
        existing_tables = await get_existing_tables(conn)
        print(f"Found {len(existing_tables)} existing tables: {sorted(existing_tables)}\n")

        for table_name, columns in SCHEMA.items():
            print(f"--- Syncing table: '{table_name}' ---")
            if table_name not in existing_tables:
                await create_table(conn, table_name, columns)
            else:
                print(f"  Table '{table_name}' exists. Checking for missing columns...")
                await sync_table_columns(conn, table_name, columns)
            print()

    await engine.dispose()
    print("✅ Migration complete! All tables and columns are up to date.")


if __name__ == "__main__":
    asyncio.run(migrate())
