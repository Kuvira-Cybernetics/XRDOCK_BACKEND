import httpx
import os
import secrets
import hashlib
import base64
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any, List

class APSService:
    def __init__(self):
        self.client_id = os.getenv("AUTODESK_CLIENT_ID", "oQTGX3R5naXNBjUFXcGwxx8SmNgWVtbDMDnDd0Gj4CETI7VZ")
        self.callback_url = os.getenv("AUTODESK_CALLBACK_URL", "http://localhost:8001/auth/autodesk/callback")
        self.base_url = "https://developer.api.autodesk.com"

    def generate_pkce(self) -> Dict[str, str]:
        """Generates a code_verifier and code_challenge for PKCE."""
        code_verifier = secrets.token_urlsafe(64)
        m = hashlib.sha256()
        m.update(code_verifier.encode('ascii'))
        code_challenge = base64.urlsafe_b64encode(m.digest()).decode('ascii').replace('=', '')
        return {"code_verifier": code_verifier, "code_challenge": code_challenge}

    def get_login_url(self, code_challenge: str, state: Optional[str] = None) -> str:
        import urllib.parse
        scopes = "data:read data:write data:create bucket:create bucket:read viewables:read user-profile:read"
        encoded_scopes = urllib.parse.quote(scopes)
        url = (
            f"{self.base_url}/authentication/v2/authorize?"
            f"response_type=code&"
            f"client_id={self.client_id}&"
            f"redirect_uri={self.callback_url}&"
            f"scope={encoded_scopes}&"
            f"code_challenge={code_challenge}&"
            f"code_challenge_method=S256"
        )
        if state:
            url += f"&state={state}"
        return url

    async def get_tokens(self, code: str, code_verifier: str) -> Dict[str, Any]:
        """Exchanges code and verifier for tokens (PKCE - no secret)."""
        url = f"{self.base_url}/authentication/v2/token"
        data = {
            "client_id": self.client_id,
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": code_verifier,
            "redirect_uri": self.callback_url
        }
        async with httpx.AsyncClient() as client:
            response = await client.post(url, data=data)
            response.raise_for_status()
            return response.json()

    async def refresh_tokens(self, refresh_token: str) -> Dict[str, Any]:
        """Refreshes tokens (PKCE - no secret)."""
        url = f"{self.base_url}/authentication/v2/token"
        data = {
            "client_id": self.client_id,
            "grant_type": "refresh_token",
            "refresh_token": refresh_token
        }
        async with httpx.AsyncClient() as client:
            response = await client.post(url, data=data)
            response.raise_for_status()
            return response.json()

    # --- Data Management API ---

    async def get_hubs(self, access_token: str) -> List[Dict[str, Any]]:
        url = f"{self.base_url}/project/v1/hubs"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json().get("data", [])

    async def get_projects(self, access_token: str, hub_id: str) -> List[Dict[str, Any]]:
        url = f"{self.base_url}/project/v1/hubs/{hub_id}/projects"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json().get("data", [])

    async def get_top_folders(self, access_token: str, hub_id: str, project_id: str) -> List[Dict[str, Any]]:
        url = f"{self.base_url}/project/v1/hubs/{hub_id}/projects/{project_id}/topFolders"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json().get("data", [])

    async def get_folder_contents(self, access_token: str, project_id: str, folder_id: str) -> List[Dict[str, Any]]:
        url = f"{self.base_url}/data/v1/projects/{project_id}/folders/{folder_id}/contents"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json().get("data", [])

    # --- Model Derivative API ---

    async def translate_to_glb(self, access_token: str, urn: str) -> Dict[str, Any]:
        import base64
        # URN must be base64 encoded without padding
        safe_urn = base64.b64encode(urn.encode()).decode().rstrip("=")
        
        url = f"{self.base_url}/modelderivative/v2/designdata/job"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        payload = {
            "input": {"urn": safe_urn},
            "output": {
                "formats": [
                    {
                        "type": "glb",
                        "views": ["2d", "3d"]
                    }
                ]
            }
        }
        async with httpx.AsyncClient() as client:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            return response.json()

    async def get_translation_status(self, access_token: str, urn: str) -> Dict[str, Any]:
        import base64
        safe_urn = base64.b64encode(urn.encode()).decode().rstrip("=")
        url = f"{self.base_url}/modelderivative/v2/designdata/{safe_urn}/manifest"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json()

    async def get_user_profile(self, access_token: str) -> Dict[str, Any]:
        """Fetches the Autodesk user profile."""
        url = f"{self.base_url}/userprofile/v1/users/@me"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json()
