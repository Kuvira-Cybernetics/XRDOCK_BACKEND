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
