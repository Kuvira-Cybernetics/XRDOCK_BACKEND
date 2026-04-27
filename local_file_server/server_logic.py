import os
import shutil
import sys
from typing import List
from datetime import datetime
from fastapi import FastAPI, UploadFile, File, HTTPException, Response
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware

def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

app = FastAPI(title="Local File Server API")

# This will be updated dynamically by the GUI
STORAGE_PATH = os.path.join(os.getcwd(), "shared_files")
os.makedirs(STORAGE_PATH, exist_ok=True)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_file_info(filename: str):
    path = os.path.join(STORAGE_PATH, filename)
    stats = os.stat(path)
    return {
        "name": filename,
        "size": stats.st_size,
        "modified": datetime.fromtimestamp(stats.st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
        "is_dir": os.path.isdir(path)
    }

@app.get("/api/files")
async def list_files():
    try:
        files = [get_file_info(f) for f in os.listdir(STORAGE_PATH)]
        # Sort: directories first, then by name
        files.sort(key=lambda x: (not x["is_dir"], x["name"].lower()))
        return files
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    try:
        file_path = os.path.join(STORAGE_PATH, file.filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        return {"message": f"Successfully uploaded {file.filename}", "filename": file.filename}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/download/{filename}")
async def download_file(filename: str):
    file_path = os.path.join(STORAGE_PATH, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(path=file_path, filename=filename)

@app.delete("/api/files/{filename}")
async def delete_file(filename: str):
    file_path = os.path.join(STORAGE_PATH, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    try:
        if os.path.isdir(file_path):
            shutil.rmtree(file_path)
        else:
            os.remove(file_path)
        return {"message": f"Deleted {filename}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Serve the Web UI
@app.get("/", response_class=HTMLResponse)
async def get_ui():
    ui_path = resource_path(os.path.join("web_ui", "index.html"))
    if os.path.exists(ui_path):
        with open(ui_path, "r", encoding="utf-8") as f:
            return f.read()
    return f"<h1>Web UI not found at {ui_path}. API is running.</h1>"

# Function to update the storage path from the GUI
def update_config(new_path: str):
    global STORAGE_PATH
    if os.path.exists(new_path):
        STORAGE_PATH = new_path
        return True
    return False
