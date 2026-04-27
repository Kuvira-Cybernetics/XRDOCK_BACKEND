import customtkinter as ctk
import socket
import threading
import uvicorn
import os
import sys
import ctypes
import argparse
from PIL import Image, ImageTk
from tkinter import filedialog
from server_logic import app, update_config
import pystray
from pystray import MenuItem as item
import datetime
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization

def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")

    return os.path.join(base_path, relative_path)

def generate_self_signed_cert(cert_path, key_path, local_ip=None):
    """Generates a self-signed certificate with Local IP support if it doesn't exist."""
    if os.path.exists(cert_path) and os.path.exists(key_path):
        return

    # Generate private key
    key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    
    # Generate certificate
    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COUNTRY_NAME, u"US"),
        x509.NameAttribute(NameOID.STATE_OR_PROVINCE_NAME, u"California"),
        x509.NameAttribute(NameOID.LOCALITY_NAME, u"San Francisco"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, u"XRDOCK"),
        x509.NameAttribute(NameOID.COMMON_NAME, u"localhost"),
    ])
    
    # Add SANs (Subject Alternative Names) for localhost and Local IP
    alt_names = [
        x509.DNSName(u"localhost"),
        x509.DNSName(u"127.0.0.1"),
    ]
    if local_ip:
        try:
            # Add as both DNS and IP if it looks like an IP
            alt_names.append(x509.DNSName(str(local_ip)))
            import ipaddress
            alt_names.append(x509.IPAddress(ipaddress.ip_address(local_ip)))
        except:
            pass

    cert = x509.CertificateBuilder().subject_name(
        subject
    ).issuer_name(
        issuer
    ).public_key(
        key.public_key()
    ).serial_number(
        x509.random_serial_number()
    ).not_valid_before(
        datetime.datetime.utcnow()
    ).not_valid_after(
        # Valid for 10 years
        datetime.datetime.utcnow() + datetime.timedelta(days=3650)
    ).add_extension(
        x509.SubjectAlternativeName(alt_names),
        critical=False,
    ).sign(key, hashes.SHA256())
        # Valid for 10 years
        datetime.datetime.utcnow() + datetime.timedelta(days=3650)
    ).add_extension(
        x509.SubjectAlternativeName([
            x509.DNSName(u"localhost"),
            x509.DNSName(u"127.0.0.1"),
        ]),
        critical=False,
    ).sign(key, hashes.SHA256())

    # Write key
    with open(key_path, "wb") as f:
        f.write(key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption(),
        ))
        
    # Write cert
    with open(cert_path, "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))

class ServerThread(threading.Thread):
    def __init__(self, port, host="0.0.0.0", ssl_cert=None, ssl_key=None):
        threading.Thread.__init__(self)
        self.port = port
        self.host = host
        self.daemon = True
        
        config_kwargs = {
            "app": app,
            "host": self.host,
            "port": self.port,
            "log_level": "info",
            "log_config": None
        }
        
        if ssl_cert and ssl_key:
            config_kwargs["ssl_certfile"] = ssl_cert
            config_kwargs["ssl_keyfile"] = ssl_key
            
        self.config = uvicorn.Config(**config_kwargs)
        self.server = uvicorn.Server(self.config)

    def run(self):
        self.server.run()

    def stop(self):
        self.server.should_exit = True

class FileServerApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        # Fix for Windows Taskbar Icon
        try:
            myappid = 'xrdock.fileserver.v1'
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)
        except:
            pass

        self.title("XRDOCK | Local File Server")
        self.geometry("650x650")
        ctk.set_appearance_mode("dark")
        
        # XRDOCK Theme Colors
        self.bg_color = "#060918"
        self.accent_color = "#00F2FF"
        self.secondary_accent = "#7F00FF"
        self.surface_color = "#0B1221"

        self.configure(fg_color=self.bg_color)

        self.server_thread = None
        self.is_running = False

        # Load Assets
        self.load_assets()
        
        # Set Window Icon
        self.set_window_icon()
        
        # UI Components
        self.setup_ui()
        self.update_ip_display()

        # Handle Window Close
        self.protocol("WM_DELETE_WINDOW", self.hide_window)
        
        # Setup System Tray
        self.setup_tray()

    def set_window_icon(self):
        logo_path = resource_path("sidebar_logo.png")
        if os.path.exists(logo_path):
            try:
                img = Image.open(logo_path)
                self.photo = ImageTk.PhotoImage(img)
                self.wm_iconphoto(True, self.photo)
            except Exception as e:
                print(f"Icon error: {e}")

    def load_assets(self):
        logo_path = resource_path("sidebar_logo.png")
        if os.path.exists(logo_path):
            img = Image.open(logo_path)
            width, height = img.size
            aspect_ratio = width / height
            target_height = 80
            target_width = int(target_height * aspect_ratio)
            self.logo_image = ctk.CTkImage(light_image=img, dark_image=img, size=(target_width, target_height))
        else:
            self.logo_image = None

    def setup_ui(self):
        # Logo and Header
        if self.logo_image:
            self.logo_label = ctk.CTkLabel(self, image=self.logo_image, text="")
            self.logo_label.pack(pady=(30, 0))

        self.header = ctk.CTkLabel(self, text="LOCAL FILE SERVER", 
                                   font=("Inter", 28, "bold"), 
                                   text_color=self.accent_color)
        self.header.pack(pady=(10, 5))

        # Status Badge
        self.status_badge = ctk.CTkLabel(self, text="SYSTEM OFFLINE", 
                                        font=("Inter", 11, "bold"),
                                        fg_color="transparent",
                                        text_color="#94a3b8")
        self.status_badge.pack(pady=(0, 20))

        # Config Frame
        self.config_frame = ctk.CTkFrame(self, fg_color=self.surface_color, corner_radius=20, border_width=1, border_color="#1e293b")
        self.config_frame.pack(pady=10, padx=50, fill="x")

        # Path Selection
        self.path_label = ctk.CTkLabel(self.config_frame, text="STORAGE PATH", font=("Inter", 10, "bold"), text_color="#64748b")
        self.path_label.grid(row=0, column=0, padx=20, pady=(20, 0), sticky="w")
        
        default_path = os.path.join(os.path.dirname(sys.executable if getattr(sys, 'frozen', False) else __file__), "shared_files")
        self.path_entry = ctk.CTkEntry(self.config_frame, width=320, height=40, fg_color="#1a1f2b", border_color="#334155")
        self.path_entry.insert(0, default_path)
        self.path_entry.grid(row=1, column=0, padx=20, pady=(5, 20), sticky="w")
        
        self.path_btn = ctk.CTkButton(self.config_frame, text="BROWSE", width=100, height=40, 
                                      fg_color="#1e293b", hover_color="#334155",
                                      command=self.browse_folder)
        self.path_btn.grid(row=1, column=1, padx=(0, 20), pady=(5, 20))

        # Port Selection
        self.port_label = ctk.CTkLabel(self.config_frame, text="SERVER PORT", font=("Inter", 10, "bold"), text_color="#64748b")
        self.port_label.grid(row=2, column=0, padx=20, pady=(0, 0), sticky="w")
        
        self.port_entry = ctk.CTkEntry(self.config_frame, width=100, height=40, fg_color="#1a1f2b", border_color="#334155")
        self.port_entry.insert(0, "8000")
        self.port_entry.grid(row=3, column=0, padx=20, pady=(5, 20), sticky="w")

        # IP and URL Display
        self.info_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.info_frame.pack(pady=20)
        
        self.ip_label = ctk.CTkLabel(self.info_frame, text="LOCAL IP: 0.0.0.0", font=("Inter", 13, "bold"), text_color="#94a3b8")
        self.ip_label.pack()
        
        url_container = ctk.CTkFrame(self.info_frame, fg_color="transparent")
        url_container.pack(pady=5)

        self.url_label = ctk.CTkLabel(url_container, text="ACCESS URL: https://0.0.0.0:8000", 
                                      font=("Inter", 15, "bold"), text_color=self.accent_color, cursor="hand2")
        self.url_label.pack(side="left")

        self.copy_btn = ctk.CTkButton(url_container, text="COPY", width=60, height=25, 
                                      fg_color="#1e293b", hover_color="#334155",
                                      font=("Inter", 10, "bold"),
                                      command=self.copy_url)
        self.copy_btn.pack(side="left", padx=10)

        # Action Button
        self.toggle_btn = ctk.CTkButton(self, text="START SERVER", font=("Inter", 16, "bold"), 
                                        height=55, width=280, corner_radius=15,
                                        fg_color=self.accent_color, text_color=self.bg_color,
                                        hover_color="#00d2ff",
                                        command=self.toggle_server)
        self.toggle_btn.pack(pady=10)

        # Bind port entry change
        self.port_entry.bind("<KeyRelease>", lambda e: self.update_ip_display())

        # Log Area
        self.log_text = ctk.CTkTextbox(self, height=80, font=("Consolas", 10), fg_color="#0d1117", border_width=1, border_color="#1e293b")
        self.log_text.pack(pady=(20, 20), padx=50, fill="both")
        self.log_text.insert("0.0", "SYSTEM READY\n")
        self.log_text.configure(state="disabled")

    def copy_url(self):
        url = self.url_label.cget("text").replace("ACCESS URL: ", "")
        self.clipboard_clear()
        self.clipboard_append(url)
        self.log(f"URL COPIED TO CLIPBOARD: {url}")
        
        # Simple feedback on button
        original_text = self.copy_btn.cget("text")
        self.copy_btn.configure(text="COPIED!", fg_color="#10b981")
        self.after(2000, lambda: self.copy_btn.configure(text=original_text, fg_color="#1e293b"))

    def browse_folder(self):
        folder = filedialog.askdirectory()
        if folder:
            self.path_entry.delete(0, "end")
            self.path_entry.insert(0, folder)
            self.log(f"Path updated to: {folder}")

    def update_ip_display(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
        except:
            ip = "127.0.0.1"
        
        port = self.port_entry.get()
        self.ip_label.configure(text=f"LOCAL IP: {ip}")
        self.url_label.configure(text=f"ACCESS URL: https://{ip}:{port}")
        return ip, port

    def log(self, message):
        self.log_text.configure(state="normal")
        self.log_text.insert("end", f"[{threading.current_thread().name}] {message.upper()}\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    def toggle_server(self):
        if not self.is_running:
            self.start_server()
        else:
            self.stop_server()

    def start_server(self):
        try:
            path = self.path_entry.get()
            port = int(self.port_entry.get())
            
            if not os.path.exists(path):
                os.makedirs(path, exist_ok=True)
                
            update_config(path)
            
            # Setup SSL
            base_dir = os.path.dirname(sys.executable if getattr(sys, 'frozen', False) else __file__)
            
            # Prioritize mkcert filenames if they exist
            mkcert_cert = os.path.join(base_dir, "localhost+2.pem")
            mkcert_key = os.path.join(base_dir, "localhost+2-key.pem")
            
            if os.path.exists(mkcert_cert) and os.path.exists(mkcert_key):
                cert_path, key_path = mkcert_cert, mkcert_key
                self.log("USING MKCERT SSL CERTIFICATES.")
            else:
                # Fallback to auto-generated ones with same filenames for consistency
                cert_path, key_path = mkcert_cert, mkcert_key
                try:
                    ip, _ = self.update_ip_display()
                    generate_self_signed_cert(cert_path, key_path, local_ip=ip)
                    self.log("AUTO-GENERATED SSL READY.")
                except Exception as ssl_err:
                    self.log(f"SSL GEN ERROR: {ssl_err}")
                    cert_path = None
                    key_path = None
                
            self.server_thread = ServerThread(port, ssl_cert=cert_path, ssl_key=key_path)
            self.server_thread.start()
            
            self.is_running = True
            self.toggle_btn.configure(text="STOP SERVER", fg_color="#ef4444", hover_color="#dc2626", text_color="white")
            self.status_badge.configure(text="SYSTEM ONLINE", text_color=self.accent_color)
            self.log(f"SERVER STARTED ON PORT {port} SERVING {path}")
            
            # Disable config while running
            self.path_entry.configure(state="disabled")
            self.port_entry.configure(state="disabled")
            self.path_btn.configure(state="disabled")
        except Exception as e:
            self.log(f"ERROR: {str(e)}")

    def stop_server(self):
        if self.server_thread:
            self.server_thread.stop()
            self.server_thread = None
            
        self.is_running = False
        self.toggle_btn.configure(text="START SERVER", fg_color=self.accent_color, text_color=self.bg_color, hover_color="#00d2ff")
        self.status_badge.configure(text="SYSTEM OFFLINE", text_color="#94a3b8")
        self.log("SERVER STOPPED.")
        
        # Re-enable config
        self.path_entry.configure(state="normal")
        self.port_entry.configure(state="normal")
        self.path_btn.configure(state="normal")

    def hide_window(self):
        self.withdraw()
        self.tray_icon.visible = True

    def show_window(self):
        self.tray_icon.visible = False
        self.deiconify()

    def quit_app(self):
        self.stop_server()
        self.tray_icon.stop()
        self.destroy()
        sys.exit(0)

    def setup_tray(self):
        logo_path = resource_path("sidebar_logo.png")
        if os.path.exists(logo_path):
            image = Image.open(logo_path)
            menu = (item('Show', self.show_window), item('Quit', self.quit_app))
            self.tray_icon = pystray.Icon("XRDOCK", image, "XRDOCK File Server", menu)
            # Run tray in a separate thread
            threading.Thread(target=self.tray_icon.run, daemon=True).start()

def run_headless(port, path):
    print(f"Starting XRDOCK File Server in headless mode...")
    print(f"Path: {path}")
    print(f"Port: {port}")
    
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)
    
    update_config(path)
    
    # Setup SSL
    base_dir = os.getcwd()
    cert_path = os.path.join(base_dir, "localhost+2.pem")
    key_path = os.path.join(base_dir, "localhost+2-key.pem")
    
    if not (os.path.exists(cert_path) and os.path.exists(key_path)):
        generate_self_signed_cert(cert_path, key_path)
    
    config = uvicorn.Config(
        app=app, 
        host="0.0.0.0", 
        port=port, 
        log_level="info",
        ssl_certfile=cert_path,
        ssl_keyfile=key_path
    )
    server = uvicorn.Server(config)
    server.run()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="XRDOCK Local File Server")
    parser.add_argument("--headless", action="store_true", help="Run without GUI")
    parser.add_argument("--port", type=int, default=8000, help="Server port")
    parser.add_argument("--path", type=str, help="Storage path")
    
    args = parser.parse_args()
    
    if args.headless:
        storage_path = args.path if args.path else os.path.join(os.getcwd(), "shared_files")
        run_headless(args.port, storage_path)
    else:
        app_gui = FileServerApp()
        if args.path:
            app_gui.path_entry.delete(0, "end")
            app_gui.path_entry.insert(0, args.path)
        if args.port:
            app_gui.port_entry.delete(0, "end")
            app_gui.port_entry.insert(0, str(args.port))
            
        app_gui.mainloop()
