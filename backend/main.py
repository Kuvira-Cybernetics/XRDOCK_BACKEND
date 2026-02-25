from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
from typing import List
import os
from dotenv import load_dotenv

load_dotenv()

from models import Issue, Project, User
from db import init_db, get_session
from dependencies import verify_firebase_token

app = FastAPI(title="XRDOCK Backend API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files for 3D models
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.on_event("startup")
async def on_startup():
    await init_db()

@app.get("/")
def read_root():
    return {"message": "Welcome to XRDOCK API"}

@app.get("/auth-status")
async def auth_status(user: dict = Depends(verify_firebase_token)):
    return {"status": "authenticated", "user": user}

@app.get("/projects", response_model=List[Project])
async def get_projects(
    session: AsyncSession = Depends(get_session),
    user: dict = Depends(verify_firebase_token)
):
    statement = select(Project)
    result = await session.execute(statement)
    projects = result.scalars().all()
    return projects

@app.post("/users", response_model=User)
async def upsert_user(
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    email = user_data.get("email")
    
    statement = select(User).where(User.uid == uid)
    result = await session.execute(statement)
    db_user = result.scalar_one_or_none()
    
    if db_user:
        # Update existing user if needed
        db_user.email = email
    else:
        # Create new user
        db_user = User(uid=uid, email=email)
        session.add(db_user)
    
    await session.commit()
    await session.refresh(db_user)
    return db_user

@app.get("/issues", response_model=List[Issue])
async def get_all_issues(
    session: AsyncSession = Depends(get_session),
    user: dict = Depends(verify_firebase_token)
):
    statement = select(Issue).order_by(Issue.id.desc())
    result = await session.execute(statement)
    return result.scalars().all()

@app.get("/issues/{project_id}", response_model=List[Issue])
async def get_issues(
    project_id: int, 
    session: AsyncSession = Depends(get_session),
    user: dict = Depends(verify_firebase_token)
):
    statement = select(Issue).where(Issue.project_id == project_id)
    result = await session.execute(statement)
    issues = result.scalars().all()
    return issues

@app.post("/issues", response_model=Issue)
async def create_issue(
    issue: Issue,
    session: AsyncSession = Depends(get_session),
    user: dict = Depends(verify_firebase_token)
):
    # Ensure the user creating the issue is the authenticated user
    issue.author_uid = user.get("uid")
    session.add(issue)
    await session.commit()
    await session.refresh(issue)
    return issue

# --- Subscription Endpoints ---
PLAN_PRICES = {
    "basic": 599,
    "pro": 999,
    "enterprise": 1299,
}

@app.get("/me", response_model=User)
async def get_current_user(
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    """Get the current logged-in user's profile & subscription status."""
    uid = user_data.get("uid")
    result = await session.execute(select(User).where(User.uid == uid))
    db_user = result.scalar_one_or_none()
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found. Please register first.")
    return db_user

@app.post("/subscribe")
async def subscribe(
    plan: str,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    """Subscribe the current user to a plan (simulated payment)."""
    if plan not in PLAN_PRICES:
        raise HTTPException(status_code=400, detail=f"Invalid plan. Choose from: {list(PLAN_PRICES.keys())}")
    
    uid = user_data.get("uid")
    result = await session.execute(select(User).where(User.uid == uid))
    db_user = result.scalar_one_or_none()
    
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found.")
    
    from datetime import datetime, timezone, timedelta
    db_user.subscription_plan = plan
    db_user.subscription_expiry = datetime.now(timezone.utc) + timedelta(days=30)
    
    await session.commit()
    await session.refresh(db_user)
    return {
        "message": f"Subscribed to {plan} plan successfully.",
        "plan": plan,
        "price": PLAN_PRICES[plan],
        "expires_at": db_user.subscription_expiry.isoformat()
    }
