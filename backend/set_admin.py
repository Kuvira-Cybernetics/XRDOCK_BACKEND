import asyncio
from sqlmodel import select
from db import init_db, get_session
from models import User
import sys

async def set_admin_by_email(email: str):
    await init_db()
    
    # We iterate manually to get one session from the generator
    async for session in get_session():
        stmt = select(User).where(User.email == email)
        result = await session.execute(stmt)
        db_users = result.scalars().all()
        
        if not db_users:
            print(f"\n[ERROR] User with email '{email}' not found in the database.")
            print("Please ensure the user has registered/logged in at least once.")
            return

        print(f"\n[INFO] Found {len(db_users)} user record(s) for email '{email}'.")
        for db_user in db_users:
            if db_user.is_admin:
                print(f" - User UID '{db_user.uid}' is already an admin.")
            else:
                db_user.is_admin = True
                session.add(db_user)
                print(f" - Promoting User UID '{db_user.uid}' to ADMIN...")
        
        await session.commit()
        print(f"\n[SUCCESS] Admin status updated for '{email}'!")
        break

if __name__ == "__main__":
    if len(sys.argv) > 1:
        email_to_set = sys.argv[1]
    else:
        print("--- XRDOCK Admin Privilege Tool ---")
        email_to_set = input("Enter the user email to set as ADMIN: ").strip()

    if not email_to_set:
        print("No email provided. Exiting.")
        sys.exit(1)

    asyncio.run(set_admin_by_email(email_to_set))
