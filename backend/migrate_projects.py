from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
# Force sync driver
if "asyncpg" in DATABASE_URL:
    SYNC_DATABASE_URL = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql+psycopg2://")
elif DATABASE_URL.startswith("postgresql://"):
    SYNC_DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://", 1)
else:
    SYNC_DATABASE_URL = DATABASE_URL

def migrate():
    print(f"Connecting to: {SYNC_DATABASE_URL}")
    engine = create_engine(SYNC_DATABASE_URL)
    with engine.connect() as conn:
        print("Adding owner_uid to project table...")
        try:
            conn.execute(text("ALTER TABLE project ADD COLUMN owner_uid VARCHAR;"))
            conn.execute(text("CREATE INDEX ix_project_owner_uid ON project (owner_uid);"))
            conn.commit()
            print("Successfully added owner_uid column.")
        except Exception as e:
            print(f"Error or already exists: {e}")

if __name__ == "__main__":
    migrate()
