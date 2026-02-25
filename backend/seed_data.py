import asyncio
from datetime import datetime, timezone, timedelta
from sqlmodel import select, SQLModel
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from db import engine, init_db
from models import Project, Issue, User

async def seed_data():
    # Ensure tables are created
    await init_db()
    
    async_session = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    
    async with async_session() as session:
        # Create Projects
        projects_data = [
            {
                "name": "Bugatti Supercar", 
                "model_filename": "bugatti.glb",
                "thumbnail_url": "https://images.unsplash.com/photo-1544636331-e26879cd4d9b?q=80&w=400&auto=format&fit=crop"
            },
            {
                "name": "Crystal Terminal Phase 1", 
                "model_filename": "bugatti.glb",
                "thumbnail_url": "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?q=80&w=400&auto=format&fit=crop"
            },
        ]
        
        seeded_projects = []
        for p_data in projects_data:
            statement = select(Project).where(Project.name == p_data["name"])
            result = await session.execute(statement)
            project = result.scalar_one_or_none()
            
            if not project:
                print(f"Seeding project: {p_data['name']}...")
                project = Project(name=p_data["name"], model_filename=p_data["model_filename"], thumbnail_url=p_data["thumbnail_url"])
                session.add(project)
                await session.commit()
                await session.refresh(project)
            else:
                print(f"Project already exists: {p_data['name']}")
            seeded_projects.append(project)

        # Seed issues for each project
        for project in seeded_projects:
            statement = select(Issue).where(Issue.project_id == project.id)
            result = await session.execute(statement)
            existing_issues = result.scalars().all()
            
            if not existing_issues:
                print(f"Seeding issues for {project.name}...")
                issues = [
                    Issue(
                        project_id=project.id,
                        author_uid="system",
                        title=f"{project.name} - Issue A",
                        description=f"Initial inspection issue for {project.name}.",
                        status="open",
                        priority="high",
                        x_coord=1.2, y_coord=5.4, z_coord=0.0
                    ),
                    Issue(
                        project_id=project.id,
                        author_uid="system",
                        title=f"{project.name} - Issue B",
                        description=f"Coordination mismatch in {project.name}.",
                        status="in-progress",
                        priority="medium",
                        x_coord=-2.5, y_coord=3.2, z_coord=2.4
                    ),
                ]
                for issue in issues:
                    session.add(issue)
                await session.commit()
                print(f"Issues seeded for {project.name} successfully.")
        else:
            print("Issues already exist.")

        # Seed Admin User
        admin_result = await session.execute(select(User).where(User.email == "tarunpeter221@gmail.com"))
        existing_admin = admin_result.scalars().first()
        if not existing_admin:
            new_admin = User(
                uid="admin_tarun_uid",
                email="tarunpeter221@gmail.com",
                name="Tarun Peter",
                is_admin=True,
                subscription_plan="enterprise",
                subscription_expiry=datetime.now(timezone.utc) + timedelta(days=3650)
            )
            session.add(new_admin)
            await session.commit()
            print("Admin user seeded.")
        else:
            print("Admin user already exists.")

if __name__ == "__main__":
    asyncio.run(seed_data())
