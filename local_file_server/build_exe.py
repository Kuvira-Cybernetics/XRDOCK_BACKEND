import PyInstaller.__main__
import os
import shutil
import customtkinter

# Ensure we are in the project directory
project_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(project_dir)

# Get CustomTkinter path
ctk_path = os.path.dirname(customtkinter.__file__)

# Clean previous builds
for folder in ['build', 'dist']:
    if os.path.exists(folder):
        shutil.rmtree(folder)

print("Starting PyInstaller build...")

PyInstaller.__main__.run([
    'app.py',
    '--onefile',
    '--noconsole',  # Keeping it for now as per user preference, but removing if it fails
    f'--add-data={ctk_path};customtkinter', # Include CustomTkinter assets
    '--add-data=web_ui;web_ui',             # Include the Web UI folder
    '--add-data=sidebar_logo.png;.',         # Include the logo
    '--icon=sidebar_logo.png',               # Set the EXE icon
    '--name=XRDOCK_FileServer',
    '--collect-all=customtkinter',           # Automatically collect all CTK dependencies
    '--collect-all=pystray',                 # Automatically collect pystray dependencies
    '--hidden-import=pystray._win32',        # Ensure Windows backend for pystray is included
    '--hidden-import=uvicorn.logging',
    '--hidden-import=uvicorn.loops',
    '--hidden-import=uvicorn.loops.auto',
    '--hidden-import=uvicorn.protocols',
    '--hidden-import=uvicorn.protocols.http',
    '--hidden-import=uvicorn.protocols.http.auto',
    '--hidden-import=uvicorn.protocols.websockets',
    '--hidden-import=uvicorn.protocols.websockets.auto',
    '--hidden-import=uvicorn.lifespan',
    '--hidden-import=uvicorn.lifespan.on',
])

print("\nBuild complete! Your executable is in the 'dist' folder.")
