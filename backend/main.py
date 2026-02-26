from fastapi import FastAPI, Depends, HTTPException, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.ext.asyncio import AsyncSession
from sqlmodel import select
import os
import uuid
from typing import List, Optional
from datetime import datetime, timezone, timedelta
from fastapi.responses import RedirectResponse
from firebase_admin import auth
from dotenv import load_dotenv

load_dotenv()

from models import Issue, Project, User, UserUpdate, ProjectCreate, IssueUpdate, PKCEState
from db import init_db, get_session
from dependencies import verify_firebase_token
from aps_service import APSService

aps = APSService()

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

# --- Autodesk Auth Endpoints ---

@app.get("/auth/autodesk/login")
async def autodesk_login(
    firebase_uid: Optional[str] = None,
    session: AsyncSession = Depends(get_session)
):
    state = str(uuid.uuid4())
    pkce = aps.generate_pkce()
    
    # Store PKCE state
    db_state = PKCEState(
        state=state,
        code_verifier=pkce["code_verifier"],
        linking_uid=firebase_uid,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=10)
    )
    session.add(db_state)
    await session.commit()
    
    return {"url": aps.get_login_url(code_challenge=pkce["code_challenge"], state=state)}

@app.get("/auth/autodesk/callback")
async def autodesk_callback(
    code: str,
    state: str,
    session: AsyncSession = Depends(get_session)
):
    try:
        # 1. Retrieve PKCE verifier
        result = await session.execute(select(PKCEState).where(PKCEState.state == state))
        db_state = result.scalar_one_or_none()
        
        if not db_state or db_state.expires_at < datetime.now(timezone.utc):
            if db_state:
                await session.delete(db_state)
                await session.commit()
            raise HTTPException(status_code=400, detail="Invalid or expired state")

        # 2. Exchange tokens
        tokens = await aps.get_tokens(code, db_state.code_verifier)
        
        # 3. Get User Profile
        profile = await aps.get_user_profile(tokens["access_token"])
        print(f"Autodesk Profile captured: {profile}")
        autodesk_id = profile.get("userId")
        email = profile.get("emailId") or profile.get("email", "")
        
        # Get name: firstName + lastName or userName
        first_name = profile.get("firstName", "")
        last_name = profile.get("lastName", "")
        name = profile.get("userName") or f"{first_name} {last_name}".strip() or "Autodesk User"
        
        if not autodesk_id:
            raise HTTPException(status_code=400, detail="Could not retrieve Autodesk ID from profile")

        # 4. Find/Create User
        if db_state.linking_uid:
            result = await session.execute(select(User).where(User.uid == db_state.linking_uid))
            db_user = result.scalar_one_or_none()
            if not db_user:
                raise HTTPException(status_code=404, detail="Linking user not found")
        else:
            # Standalone login: find by autodesk_id
            result = await session.execute(select(User).where(User.autodesk_id == autodesk_id))
            db_user = result.scalar_one_or_none()
            
            if not db_user:
                # Create new user
                new_uid = f"autodesk:{autodesk_id}"
                db_user = User(uid=new_uid, email=email, name=name, autodesk_id=autodesk_id)
                session.add(db_user)

        # 5. Update user info
        db_user.autodesk_id = autodesk_id
        db_user.email = email
        db_user.name = name
        db_user.autodesk_access_token = tokens["access_token"]
        
        # Also sync to Firebase Auth record for standard UI widgets
        try:
            auth.update_user(
                db_user.uid,
                display_name=name,
                email=email
            )
        except Exception as fe:
            print(f"Firebase profile sync warning: {fe}")
        db_user.autodesk_refresh_token = tokens["refresh_token"]
        db_user.autodesk_token_expires = datetime.now(timezone.utc) + timedelta(seconds=tokens["expires_in"])
        
        # 6. Cleanup state
        await session.delete(db_state)
        await session.commit()
        await session.refresh(db_user)

        # 7. Generate Firebase Custom Token
        custom_token_bytes = auth.create_custom_token(db_user.uid)
        custom_token = custom_token_bytes.decode('utf-8') if isinstance(custom_token_bytes, bytes) else custom_token_bytes

        # 8. Redirect to frontend
        frontend_url = os.getenv("FRONTEND_URL", "http://localhost:5000")
        redirect_url = f"{frontend_url}/#/login?token={custom_token}"
        print(f"Redirecting user to: {redirect_url}")
        return RedirectResponse(url=redirect_url)

    except Exception as e:
        print(f"Autodesk callback error: {e}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/autodesk/hubs")
async def get_autodesk_hubs(
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    # Get user from DB to get their Autodesk token
    result = await session.execute(select(User).where(User.uid == uid))
    user = result.scalar_one_or_none()
    if not user or not user.autodesk_access_token:
        raise HTTPException(status_code=401, detail="Autodesk not linked")
    
    try:
        hubs = await aps.get_hubs(user.autodesk_access_token)
        return hubs
    except Exception as e:
        # Check if token expired and refresh...
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/autodesk/projects/{hub_id}")
async def get_autodesk_projects(
    hub_id: str,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    result = await session.execute(select(User).where(User.uid == uid))
    user = result.scalar_one_or_none()
    if not user or not user.autodesk_access_token:
        raise HTTPException(status_code=401, detail="Autodesk not linked")
    return await aps.get_projects(user.autodesk_access_token, hub_id)

@app.get("/autodesk/folders/{hub_id}/{project_id}")
async def get_autodesk_folders(
    hub_id: str,
    project_id: str,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    result = await session.execute(select(User).where(User.uid == uid))
    user = result.scalar_one_or_none()
    if not user or not user.autodesk_access_token:
        raise HTTPException(status_code=401, detail="Autodesk not linked")
    return await aps.get_top_folders(user.autodesk_access_token, hub_id, project_id)

@app.get("/autodesk/folder-contents/{project_id}/{folder_id}")
async def get_autodesk_folder_contents(
    project_id: str,
    folder_id: str,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    result = await session.execute(select(User).where(User.uid == uid))
    user = result.scalar_one_or_none()
    if not user or not user.autodesk_access_token:
        raise HTTPException(status_code=401, detail="Autodesk not linked")
    return await aps.get_folder_contents(user.autodesk_access_token, project_id, folder_id)

@app.post("/autodesk/import")
async def import_autodesk_file(
    import_data: dict, # {project_id: str, item_id: str, name: str}
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    # Get user for token
    result = await session.execute(select(User).where(User.uid == uid))
    user = result.scalar_one_or_none()
    if not user or not user.autodesk_access_token:
        raise HTTPException(status_code=401, detail="Autodesk not linked")
    
    aps_project_id = import_data.get("project_id")
    item_id = import_data.get("item_id")
    name = import_data.get("name")
    
    try:
        # 1. Get the URN for the item (latest version)
        # Note: In a production app, you'd fetch the latest version's URN.
        # For simplicity, we assume the item_id can be used as a base for the URN if it's already a versioned URN
        # or we fetch it. Let's assume the frontend might need to pass the version URN.
        # But we can also fetch it here.
        urn = item_id # Placeholder: ideally fetch version URN
        
        # 2. Trigger translation
        translation_result = await aps.translate_to_glb(user.autodesk_access_token, urn)
        
        # 3. Create a project in our DB
        db_project = Project(
            name=f"[Importing] {name}",
            owner_uid=user_data.get("uid"),
            model_filename="bugatti.glb", # Temporary placeholder until translation done
        )
        session.add(db_project)
        await session.commit()
        await session.refresh(db_project)
        
        # 4. In a real app, you'd set up a webhook or background task to poll status
        # and update the project once the GLB is ready for download.
        
        return {
            "status": "success",
            "project_id": db_project.id,
            "translation_status": translation_result.get("result", "success")
        }
    except Exception as e:
        print(f"Import error: {e}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/projects", response_model=List[Project])
async def get_projects(
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    statement = select(Project).where(Project.owner_uid == uid).order_by(Project.id.desc())
    result = await session.execute(statement)
    projects = result.scalars().all()
    return projects

@app.post("/projects", response_model=Project)
async def create_project(
    project_in: ProjectCreate,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    db_project = Project(
        name=project_in.name,
        owner_uid=uid
    )
    session.add(db_project)
    await session.commit()
    await session.refresh(db_project)
    return db_project

@app.put("/projects/{project_id}", response_model=Project)
async def update_project(
    project_id: int,
    project_in: ProjectCreate,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    # Only allow if owner
    statement = select(Project).where(Project.id == project_id, Project.owner_uid == uid)
    result = await session.execute(statement)
    db_project = result.scalar_one_or_none()
    if not db_project:
        raise HTTPException(status_code=404, detail="Project not found or access denied")
    
    db_project.name = project_in.name
        
    await session.commit()
    await session.refresh(db_project)
    return db_project

@app.delete("/projects/{project_id}")
async def delete_project(
    project_id: int,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    statement = select(Project).where(Project.id == project_id, Project.owner_uid == uid)
    result = await session.execute(statement)
    db_project = result.scalar_one_or_none()
    
    if not db_project:
        raise HTTPException(status_code=404, detail="Project not found or access denied")
    
    # Clean up the model file if it's not the default
    model_filename = db_project.model_filename
    if model_filename and model_filename != "bugatti.glb":
        file_path = os.path.join("static", "models", model_filename)
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
            except Exception as e:
                print(f"Error deleting model file {file_path}: {e}")
    
    await session.delete(db_project)
    await session.commit()
    return {"ok": True}

@app.post("/projects/{project_id}/model")
async def upload_project_model(
    project_id: int,
    file: UploadFile = File(...),
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    statement = select(Project).where(Project.id == project_id, Project.owner_uid == uid)
    result = await session.execute(statement)
    db_project = result.scalar_one_or_none()
    
    if not db_project:
        raise HTTPException(status_code=404, detail="Project not found or access denied")
    
    # Save the file
    filename = f"model_{project_id}_{file.filename}"
    file_path = os.path.join("static", "models", filename)
    
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    
    with open(file_path, "wb") as buffer:
        content = await file.read()
        buffer.write(content)
    
    db_project.model_filename = filename
    await session.commit()
    await session.refresh(db_project)
    
    return {"model_filename": filename}

@app.post("/users", response_model=User)
async def upsert_user(
    user_update: UserUpdate = None,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    email = user_data.get("email")
    
    statement = select(User).where(User.uid == uid)
    result = await session.execute(statement)
    db_user = result.scalar_one_or_none()
    
    if db_user:
        # Update existing user
        db_user.email = email
        if user_update:
            update_data = user_update.model_dump(exclude_unset=True)
            for key, value in update_data.items():
                setattr(db_user, key, value)
    else:
        # Create new user
        db_user = User(uid=uid, email=email)
        if user_update:
            update_data = user_update.model_dump(exclude_unset=True)
            for key, value in update_data.items():
                setattr(db_user, key, value)
        session.add(db_user)
    
    await session.commit()
    await session.refresh(db_user)
    return db_user

@app.get("/users", response_model=List[User])
async def get_all_users(
    session: AsyncSession = Depends(get_session),
    user: dict = Depends(verify_firebase_token)
):
    # In a real app, verify `user` is an admin before returning all users
    statement = select(User).order_by(User.id.desc())
    result = await session.execute(statement)
    return result.scalars().all()

@app.put("/users/{user_id}", response_model=User)
async def update_user_admin(
    user_id: int,
    user_update: UserUpdate,
    session: AsyncSession = Depends(get_session),
    user: dict = Depends(verify_firebase_token)
):
    # In a real app, verify `user` is an admin
    db_user = await session.get(User, user_id)
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    update_data = user_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_user, key, value)
        
    await session.commit()
    await session.refresh(db_user)
    return db_user

@app.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    session: AsyncSession = Depends(get_session),
    user: dict = Depends(verify_firebase_token)
):
    # In a real app, verify `user` is an admin
    db_user = await session.get(User, user_id)
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    await session.delete(db_user)
    await session.commit()
    return {"ok": True}

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
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    # Verify project ownership
    statement = select(Project).where(Project.id == project_id, Project.owner_uid == uid)
    result = await session.execute(statement)
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Project not found or access denied")
        
    statement = select(Issue).where(Issue.project_id == project_id)
    result = await session.execute(statement)
    issues = result.scalars().all()
    return issues

@app.post("/issues", response_model=Issue)
async def create_issue(
    issue: Issue,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    # Verify project ownership
    statement = select(Project).where(Project.id == issue.project_id, Project.owner_uid == uid)
    result = await session.execute(statement)
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Project not found or access denied")

    # Ensure the user creating the issue is the authenticated user
    issue.author_uid = uid
    session.add(issue)
    await session.commit()
    await session.refresh(issue)
    return issue

@app.put("/issues/{issue_id}", response_model=Issue)
async def update_issue(
    issue_id: int,
    issue_update: IssueUpdate,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    db_issue = await session.get(Issue, issue_id)
    if not db_issue:
        raise HTTPException(status_code=404, detail="Issue not found")
        
    # Verify project ownership
    statement = select(Project).where(Project.id == db_issue.project_id, Project.owner_uid == uid)
    result = await session.execute(statement)
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")

    update_data = issue_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_issue, key, value)
        
    await session.commit()
    await session.refresh(db_issue)
    return db_issue

@app.delete("/issues/{issue_id}")
async def delete_issue(
    issue_id: int,
    session: AsyncSession = Depends(get_session),
    user_data: dict = Depends(verify_firebase_token)
):
    uid = user_data.get("uid")
    db_issue = await session.get(Issue, issue_id)
    if not db_issue:
        raise HTTPException(status_code=404, detail="Issue not found")
        
    # Verify project ownership
    statement = select(Project).where(Project.id == db_issue.project_id, Project.owner_uid == uid)
    result = await session.execute(statement)
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Access denied")

    await session.delete(db_issue)
    await session.commit()
    return {"ok": True}

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
