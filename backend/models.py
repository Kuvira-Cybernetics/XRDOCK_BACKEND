from sqlmodel import SQLModel, Field
from typing import Optional
from datetime import datetime, timezone
from sqlalchemy import Column, DateTime, ForeignKey, Integer

class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    uid: str = Field(index=True, unique=True) # Firebase UID
    email: str
    name: Optional[str] = None
    is_admin: bool = Field(default=False)
    # --- Contact Info ---
    profile_image: Optional[str] = None
    job_title: Optional[str] = None
    phone_number: Optional[str] = None
    linkedin_url: Optional[str] = None
    
    # --- Company Info ---
    company_name: Optional[str] = None
    company_website: Optional[str] = None
    industry: Optional[str] = None
    employee_count: Optional[str] = None
    country: Optional[str] = None
    
    # --- Use Case ---
    project_type: Optional[str] = None
    expected_seats: Optional[int] = None
    
    # --- Settings ---
    local_sync_path: Optional[str] = None
    bim_upload_hub_id: Optional[str] = None
    bim_upload_hub_name: Optional[str] = None
    bim_upload_project_id: Optional[str] = None
    bim_upload_project_name: Optional[str] = None
    bim_upload_folder_id: Optional[str] = None
    bim_upload_folder_name: Optional[str] = None
    
    # --- Billing / Subscription ---
    subscription_plan: Optional[str] = Field(default=None) # basic, pro, enterprise
    subscription_expiry: Optional[datetime] = Field(default=None, sa_column=Column(DateTime(timezone=True)))

    # --- Autodesk Info ---
    autodesk_id: Optional[str] = None
    autodesk_code_verifier: Optional[str] = None
    autodesk_access_token: Optional[str] = None
    autodesk_refresh_token: Optional[str] = None
    autodesk_token_expires: Optional[datetime] = Field(default=None, sa_column=Column(DateTime(timezone=True)))

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), sa_column=Column(DateTime(timezone=True)))

class UserUpdate(SQLModel):
    name: Optional[str] = None
    profile_image: Optional[str] = None
    job_title: Optional[str] = None
    phone_number: Optional[str] = None
    linkedin_url: Optional[str] = None
    company_name: Optional[str] = None
    company_website: Optional[str] = None
    industry: Optional[str] = None
    employee_count: Optional[str] = None
    country: Optional[str] = None
    project_type: Optional[str] = None
    expected_seats: Optional[int] = None
    local_sync_path: Optional[str] = None
    bim_upload_hub_id: Optional[str] = None
    bim_upload_hub_name: Optional[str] = None
    bim_upload_project_id: Optional[str] = None
    bim_upload_project_name: Optional[str] = None
    bim_upload_folder_id: Optional[str] = None
    bim_upload_folder_name: Optional[str] = None

class ProjectCreate(SQLModel):
    name: str

class ProjectUpdate(SQLModel):
    name: Optional[str] = None
    loaded_model_offset_position: Optional[str] = None
    loaded_model_offset_rotation: Optional[str] = None
    loaded_model_offset_scale: Optional[str] = None
    vrmenu_model_position: Optional[str] = None
    vrmenu_model_scale: Optional[str] = None
    created_model_center: Optional[str] = None
    show_selection_set_index: Optional[str] = None
    list_of_teleport_locations: Optional[str] = None
    list_of_ar_location_file_path: Optional[str] = None
    list_of_custom_model_data: Optional[str] = None
    list_of_custom_model_xrpath: Optional[str] = None
    arcount_stamp: Optional[str] = None
    list_of_rules: Optional[str] = None
    list_of_marker_issue: Optional[str] = None
    list_of_marker_lable: Optional[str] = None
    last_teleported_location: Optional[str] = None
    project_geometry_path: Optional[str] = None
    project_material_path: Optional[str] = None
    project_udata_path: Optional[str] = None
    teleport_last_index: Optional[int] = None
    ruler_last_index: Optional[int] = None
    marker_issue_last_index: Optional[int] = None
    marker_lable_last_index: Optional[int] = None

class IssueUpdate(SQLModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    priority: Optional[str] = None

class Project(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    owner_uid: Optional[str] = Field(default=None, index=True) # Links to User.uid
    model_filename: Optional[str] = Field(default=None)

    # --- Unity Metadata ---
    loaded_model_offset_position: Optional[str] = None
    loaded_model_offset_rotation: Optional[str] = None
    loaded_model_offset_scale: Optional[str] = None
    vrmenu_model_position: Optional[str] = None
    vrmenu_model_scale: Optional[str] = None
    created_model_center: Optional[str] = None
    show_selection_set_index: Optional[str] = None
    list_of_teleport_locations: Optional[str] = None
    list_of_ar_location_file_path: Optional[str] = None
    list_of_custom_model_data: Optional[str] = None
    list_of_custom_model_xrpath: Optional[str] = None
    arcount_stamp: Optional[str] = None
    list_of_rules: Optional[str] = None
    list_of_marker_issue: Optional[str] = None
    list_of_marker_lable: Optional[str] = None
    last_teleported_location: Optional[str] = None
    project_geometry_path: Optional[str] = None
    project_material_path: Optional[str] = None
    project_udata_path: Optional[str] = None
    teleport_last_index: Optional[int] = None
    ruler_last_index: Optional[int] = None
    marker_issue_last_index: Optional[int] = None
    marker_lable_last_index: Optional[int] = None

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), sa_column=Column(DateTime(timezone=True)))

class Issue(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    project_id: int = Field(sa_column=Column(Integer, ForeignKey("project.id", ondelete="CASCADE"), index=True))
    author_uid: str = Field(index=True) # Links to User.uid
    title: str
    description: Optional[str] = None
    status: str = Field(default="open")
    priority: str = Field(default="medium") # urgent, high, medium, low
    
    # 3D Coordinates
    x_coord: Optional[float] = None
    y_coord: Optional[float] = None
    z_coord: Optional[float] = None

class PKCEState(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    state: str = Field(index=True, unique=True)
    code_verifier: str
    linking_uid: Optional[str] = None # Firebase UID if linking
    expires_at: datetime = Field(sa_column=Column(DateTime(timezone=True)))
