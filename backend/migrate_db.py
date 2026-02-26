import asyncio
import os
from sqlalchemy import text
from db import engine

async def check_schema():
    async with engine.connect() as conn:
        result = await conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'user'"))
        columns = [row[0] for row in result.fetchall()]
        print(f"Columns in 'user' table: {columns}")
        
        if 'autodesk_id' not in columns:
            print("Missing 'autodesk_id' column. Adding it...")
            await conn.execute(text("ALTER TABLE \"user\" ADD COLUMN autodesk_id VARCHAR"))
            await conn.commit()
            print("Column 'autodesk_id' added.")
        
        if 'autodesk_code_verifier' not in columns:
            print("Missing 'autodesk_code_verifier' column. Adding it...")
            await conn.execute(text("ALTER TABLE \"user\" ADD COLUMN autodesk_code_verifier VARCHAR"))
            await conn.commit()
            print("Column 'autodesk_code_verifier' added.")

    async with engine.connect() as conn:
        result = await conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'pkcestate'"))
        columns = [row[0] for row in result.fetchall()]
        print(f"Columns in 'pkcestate' table: {columns}")
        
        if 'linking_uid' not in columns:
            print("Missing 'linking_uid' column. Adding it...")
            await conn.execute(text("ALTER TABLE pkcestate ADD COLUMN linking_uid VARCHAR"))
            await conn.commit()
            print("Column 'linking_uid' added.")

if __name__ == "__main__":
    asyncio.run(check_schema())
