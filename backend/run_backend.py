import os
import sys
import subprocess

def main():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    venv_dir = os.path.join(current_dir, "venv")
    
    # Check if we are already running inside a virtual environment
    is_venv = sys.prefix != sys.base_prefix
    
    if not is_venv:
        # Determine the path to the venv's python executable
        if os.name == 'nt':
            python_exe = os.path.join(venv_dir, "Scripts", "python.exe")
        else:
            python_exe = os.path.join(venv_dir, "bin", "python")
            
        if os.path.exists(python_exe):
            print(f"Activating virtual environment: {venv_dir}")
            # Re-execute this script using the virtual environment's Python
            sys.exit(subprocess.call([python_exe] + sys.argv))
        else:
            print(f"Warning: Virtual environment not found at {venv_dir}.")
            print("Falling back to system Python.")

    # We are now inside the venv (or a venv couldn't be found)
    import uvicorn
    print("Starting XRDOCK Backend on port 8001...")
    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True)

if __name__ == "__main__":
    main()
