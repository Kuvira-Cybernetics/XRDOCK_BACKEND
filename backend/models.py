from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime, timezone
from sqlalchemy import Column, DateTime

class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    uid: str = Field(index=True, unique=True) # Firebase UID
    email: str
    name: Optional[str] = None
    is_admin: bool = Field(default=False)
    subscription_plan: Optional[str] = Field(default=None) # basic, pro, enterprise
    subscription_expiry: Optional[datetime] = Field(default=None, sa_column=Column(DateTime(timezone=True)))
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), sa_column=Column(DateTime(timezone=True)))

class Project(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    model_filename: str = Field(default="bugatti.glb")
    thumbnail_url: Optional[str] = Field(default=None)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), sa_column=Column(DateTime(timezone=True)))

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
