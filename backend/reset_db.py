import asyncio
from db import engine
from models import SQLModel

async def reset_db():
    async with engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.drop_all)
    print("Database tables dropped successfully.")

if __name__ == "__main__":
    asyncio.run(reset_db())
