# XRDOCK Local File Server - User Guide

The **XRDOCK Local File Server** is a lightweight, high-performance tool designed to turn any Windows machine into a local file-sharing hub. It allows you to upload and download files via a web interface or API without requiring any external database or complex configuration.

---

## 🚀 Getting Started

1.  **Launch the App**: Double-click `XRDOCK_FileServer.exe`.
2.  **Configure Storage**: Select the folder you want to share using the **BROWSE** button.
3.  **Set Port**: Enter the port number (default is `8000`).
4.  **Start Server**: Click the **START SERVER** button.
5.  **Access the UI**: Open the **Access URL** displayed in your browser (e.g., `http://192.168.1.10:8000`).

---

## 🛠 Features

### 🖥 GUI Mode
- **Storage Path**: The folder on your computer where files will be stored. If the folder doesn't exist, the app will create it for you.
- **Dynamic URL**: As you change the port, the access URL updates instantly.
- **Copy URL Button**: Click **COPY** to immediately grab the server address for sharing.
- **System Tray (Background Mode)**: Closing the window **will not** stop the server. The app minimizes to the system tray (bottom-right corner of your taskbar). 
    - *To Restore*: Double-click the tray icon.
    - *To Quit*: Right-click the tray icon and select **Quit**.

### ⌨ Headless / CLI Mode
For advanced users, the server can be run directly from the Command Prompt (CMD) without a graphical interface.

**Command Syntax:**
```bash
XRDOCK_FileServer.exe --headless --port <PORT> --path "<STORAGE_PATH>"
```
**Example:**
```bash
XRDOCK_FileServer.exe --headless --port 8080 --path "C:\SharedFiles"
```

---

## 📂 How It Works (No Database Required)
- **Local Storage**: All files are stored directly on your hard drive in the folder you selected. 
- **Direct Access**: When you upload a file through the web interface, it appears instantly in your local folder.
- **Security**: The server is only accessible on your local network unless you have configured port forwarding on your router.

---

## 🌐 Web Interface
Once the server is running, the web interface allows you to:
- **View Files**: See a list of all files in the storage directory.
- **Upload**: Drag and drop or select files to upload to the server.
- **Download**: Click any file to download it to your device.
- **Delete**: Remove files directly from the web interface.

---

## 🔌 API Documentation

For developers, the server provides a simple REST API to interact with files programmatically.

### 1. List Files
**Endpoint**: `GET /api/files`  
**Description**: Returns a JSON list of all files and directories in the storage path.

### 2. Upload File
**Endpoint**: `POST /api/upload`  
**Body**: `multipart/form-data`  
**Field**: `file` (The file to upload)  
**Example (curl)**:
```bash
curl -X POST http://localhost:8000/api/upload -F "file=@photo.jpg"
```

### 3. Download File
**Endpoint**: `GET /api/download/{filename}`  
**Description**: Downloads the specified file.  
**Example**: `http://localhost:8000/api/download/document.pdf`

### 4. Delete File
**Endpoint**: `DELETE /api/files/{filename}`  
**Description**: Permanently deletes the specified file from the server.

---

## 📋 System Requirements
- **OS**: Windows 10 / 11
- **Network**: A local area network (Wi-Fi or Ethernet) for multi-device access.
