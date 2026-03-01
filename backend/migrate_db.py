import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
import os
from dotenv import load_dotenv

# Load ENV
load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

async def migrate():
    if not DATABASE_URL:
        print("Error: DATABASE_URL not found in environment.")
        return

    engine = create_async_engine(DATABASE_URL)
    
    async with engine.begin() as conn:
        # --- Project Table ---
        print("Checking 'project' table columns...")
        res = await conn.execute(text(
            "SELECT column_name FROM information_schema.columns WHERE table_name = 'project'"
        ))
        existing_project_cols = {row[0] for row in res.fetchall()}

        project_columns = {
            "loaded_model_offset_position": "VARCHAR",
            "loaded_model_offset_rotation": "VARCHAR",
            "loaded_model_offset_scale": "VARCHAR",
            "vrmenu_model_position": "VARCHAR",
            "vrmenu_model_scale": "VARCHAR",
            "created_model_center": "VARCHAR",
            "show_selection_set_index": "VARCHAR",
            "list_of_teleport_locations": "VARCHAR",
            "list_of_ar_location_file_path": "VARCHAR",
            "list_of_custom_model_data": "VARCHAR",
            "list_of_custom_model_xrpath": "VARCHAR",
            "arcount_stamp": "VARCHAR",
            "list_of_rules": "VARCHAR",
            "list_of_marker_issue": "VARCHAR",
            "list_of_marker_lable": "VARCHAR",
            "last_teleported_location": "VARCHAR",
            "project_geometry_path": "VARCHAR",
            "project_material_path": "VARCHAR",
            "project_udata_path": "VARCHAR",
            "teleport_last_index": "INTEGER",
            "ruler_last_index": "INTEGER",
            "marker_issue_last_index": "INTEGER",
            "marker_lable_last_index": "INTEGER"
        }

        for col_name, col_type in project_columns.items():
            if col_name not in existing_project_cols:
                print(f"Adding column '{col_name}' to 'project'...")
                await conn.execute(text(f"ALTER TABLE project ADD COLUMN {col_name} {col_type}"))
            else:
                print(f"Column '{col_name}' already exists in 'project'.")

        # --- User Table ---
        print("\nChecking 'user' table columns...")
        res = await conn.execute(text(
            "SELECT column_name FROM information_schema.columns WHERE table_name = 'user'"
        ))
        existing_user_cols = {row[0] for row in res.fetchall()}

        user_columns = {
            "profile_image": "VARCHAR",
            "job_title": "VARCHAR",
            "phone_number": "VARCHAR",
            "linkedin_url": "VARCHAR",
            "company_name": "VARCHAR",
            "company_website": "VARCHAR",
            "industry": "VARCHAR",
            "employee_count": "VARCHAR",
            "country": "VARCHAR",
            "project_type": "VARCHAR",
            "expected_seats": "INTEGER"
        }

        for col_name, col_type in user_columns.items():
            if col_name not in existing_user_cols:
                print(f"Adding column '{col_name}' to 'user'...")
                # Use double quotes for "user" table because it's a reserved word in PG
                await conn.execute(text(f'ALTER TABLE "user" ADD COLUMN "{col_name}" {col_type}'))
            else:
                print(f"Column '{col_name}' already exists in 'user'.")

        # --- Issue Table ---
        print("\nChecking 'issue' table...")
        res = await conn.execute(text(
            "SELECT count(*) FROM information_schema.tables WHERE table_name = 'issue'"
        ))
        if res.scalar() == 0:
            print("Creating 'issue' table...")
            # We can use SQLModel's metadata but it's easier to just run the CREATE TABLE if we want reliability
            # Or just use run_sync
            from models import Issue
            from sqlmodel import SQLModel
            def create_tables(connection):
                SQLModel.metadata.create_all(connection, tables=[Issue.__table__])
            await conn.run_sync(create_tables)
        else:
            print("'issue' table already exists.")

    await engine.dispose()
    print("\nMigration complete!")

if __name__ == "__main__":
    asyncio.run(migrate())
