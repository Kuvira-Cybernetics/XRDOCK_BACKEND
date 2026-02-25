from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime, timezone

class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    uid: str = Field(index=True, unique=True) # Firebase UID
    email: str = Field(index=True)
    name: Optional[str] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now())

class Project(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(index=True)
    model_filename: str = Field(default="bugatti.glb")
    created_at: datetime = Field(default_factory=lambda: datetime.now())

class Issue(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    project_id: int = Field(foreign_key="project.id", index=True)
    author_uid: str = Field(index=True) # Links to User.uid
    title: str
    description: Optional[str] = None
    status: str = Field(default="open")
    priority: str = Field(default="medium") # urgent, high, medium, low
    
    # 3D Coordinates
    x_coord: float
    y_coord: float
    z_coord: float
