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
        self.callback_url = "http://localhost:8001/auth/autodesk/callback"
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
        import urllib.parse
        safe_hub_id = urllib.parse.quote(hub_id)
        url = f"{self.base_url}/project/v1/hubs/{safe_hub_id}/projects"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json().get("data", [])

    async def get_top_folders(self, access_token: str, hub_id: str, project_id: str) -> List[Dict[str, Any]]:
        import urllib.parse
        safe_hub_id = urllib.parse.quote(hub_id)
        safe_project_id = urllib.parse.quote(project_id)
        url = f"{self.base_url}/project/v1/hubs/{safe_hub_id}/projects/{safe_project_id}/topFolders"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json().get("data", [])

    async def get_folder_contents(self, access_token: str, project_id: str, folder_id: str) -> List[Dict[str, Any]]:
        import urllib.parse
        safe_project_id = urllib.parse.quote(project_id)
        safe_folder_id = urllib.parse.quote(folder_id, safe='')
        url = f"{self.base_url}/data/v1/projects/{safe_project_id}/folders/{safe_folder_id}/contents"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            return response.json().get("data", [])

    async def create_folder(self, access_token: str, project_id: str, parent_folder_id: str, folder_name: str) -> str:
        """Creates a subfolder in the given parent folder if it doesn't exist, returning its ID."""
        import urllib.parse
        safe_project_id = urllib.parse.quote(project_id)
        
        # 1. Check if it already exists
        contents = await self.get_folder_contents(access_token, project_id, parent_folder_id)
        for item in contents:
            if item.get("type") == "folders" and item.get("attributes", {}).get("displayName") == folder_name:
                return item["id"]
                
        # 2. Get the parents extension type (required for Autodesk BIM360 vs ACC compatibility)
        parent_url = f"{self.base_url}/data/v1/projects/{safe_project_id}/folders/{parent_folder_id}"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            parent_resp = await client.get(parent_url, headers=headers)
            parent_resp.raise_for_status()
            parent_data = parent_resp.json()
            extension_type = parent_data["data"]["attributes"]["extension"]["type"]
            
            # 3. Create the new folder
            create_url = f"{self.base_url}/data/v1/projects/{safe_project_id}/folders"
            payload = {
                "jsonapi": {"version": "1.0"},
                "data": {
                    "type": "folders",
                    "attributes": {
                        "name": folder_name,
                        "extension": {
                            "type": extension_type,
                            "version": "1.0"
                        }
                    },
                    "relationships": {
                        "parent": {
                            "data": {
                                "type": "folders",
                                "id": parent_folder_id
                            }
                        }
                    }
                }
            }
            create_headers = {
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/vnd.api+json"
            }
            create_resp = await client.post(create_url, headers=create_headers, json=payload)
            create_resp.raise_for_status()
            return create_resp.json()["data"]["id"]

    async def get_item_tip_version(self, access_token: str, project_id: str, item_id: str) -> str:
        """Returns the URN of the latest version (tip) of an item."""
        import urllib.parse
        safe_project_id = urllib.parse.quote(project_id)
        safe_item_id = urllib.parse.quote(item_id, safe='')
        url = f"{self.base_url}/data/v1/projects/{safe_project_id}/items/{safe_item_id}"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            data = response.json()
            return data["data"]["relationships"]["tip"]["data"]["id"]

    async def get_version_download_url(self, access_token: str, project_id: str, version_urn: str) -> str:
        """Gets a signed S3 download URL for a file version."""
        import urllib.parse
        safe_project_id = urllib.parse.quote(project_id)
        safe_version_urn = urllib.parse.quote(version_urn, safe='')
        url = f"{self.base_url}/data/v1/projects/{safe_project_id}/versions/{safe_version_urn}"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
            data = response.json()
            
            storage_urn = data["data"]["relationships"]["storage"]["data"]["id"]
            
            # storage_urn format: urn:adsk.objects:os.object:wip.eu.1/....
            # Extract bucketKey and objectKey
            urn_parts = storage_urn.split(':')
            if len(urn_parts) >= 4:
                bucket_and_object = urn_parts[-1].split('/')
                bucket_key = bucket_and_object[0]
                object_key = '/'.join(bucket_and_object[1:])
                
                s3_url = f"{self.base_url}/oss/v2/buckets/{bucket_key}/objects/{urllib.parse.quote(object_key, safe='')}/signeds3download"
                s3_response = await client.get(s3_url, headers=headers)
                s3_response.raise_for_status()
                return s3_response.json()["url"]
            raise ValueError("Failed to parse storage URN")

    async def upload_to_folder(self, access_token: str, project_id: str, folder_id: str, file_name: str, file_content: bytes) -> Dict[str, Any]:
        """Uploads a file directly to an Autodesk folder by creating a storage location, uploading, and then creating an item version."""
        import urllib.parse
        safe_project_id = urllib.parse.quote(project_id)
        safe_folder_id = urllib.parse.quote(folder_id, safe='')
        
        # 1. Create a storage location
        storage_url = f"{self.base_url}/data/v1/projects/{safe_project_id}/storage"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/vnd.api+json"
        }
        storage_payload = {
            "jsonapi": {"version": "1.0"},
            "data": {
                "type": "objects",
                "attributes": {
                    "name": file_name
                },
                "relationships": {
                    "target": {
                        "data": {"type": "folders", "id": folder_id}
                    }
                }
            }
        }
        async with httpx.AsyncClient() as client:
            storage_resp = await client.post(storage_url, headers=headers, json=storage_payload)
            storage_resp.raise_for_status()
            storage_data = storage_resp.json()
            object_id = storage_data["data"]["id"]
            
            # Extract bucketKey and objectName from object_id (urn:adsk.objects:os.object:bucketKey/objectName)
            urn_parts = object_id.split(':')
            bucket_and_object = urn_parts[-1].split('/')
            bucket_key = bucket_and_object[0]
            object_key = '/'.join(bucket_and_object[1:])
            
            safe_object_key = urllib.parse.quote(object_key, safe='')
            
            # 2. Get signed S3 URL
            signed_url_endpoint = f"{self.base_url}/oss/v2/buckets/{bucket_key}/objects/{safe_object_key}/signeds3upload"
            signed_url_resp = await client.get(signed_url_endpoint, headers=headers)
            signed_url_resp.raise_for_status()
            signed_url_data = signed_url_resp.json()
            
            s3_upload_url = signed_url_data["urls"][0]
            upload_key = signed_url_data["uploadKey"]
            
            # 3. Upload exactly to the S3 URL (no Authorization header for AWS)
            s3_headers = {"Content-Type": "application/octet-stream"}
            s3_resp = await client.put(s3_upload_url, headers=s3_headers, content=file_content)
            s3_resp.raise_for_status()
            
            # 4. Finalize the upload
            finalize_payload = {"uploadKey": upload_key}
            finalize_headers = {
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json"
            }
            finalize_resp = await client.post(
                signed_url_endpoint,
                headers=finalize_headers,
                json=finalize_payload
            )
            finalize_resp.raise_for_status()
            
            # 5. Create the Item and Version
            item_url = f"{self.base_url}/data/v1/projects/{safe_project_id}/items"
            item_payload = {
                "jsonapi": {"version": "1.0"},
                "data": {
                    "type": "items",
                    "attributes": {
                        "displayName": file_name,
                        "extension": {
                            "type": "items:autodesk.bim360:File",
                            "version": "1.0"
                        }
                    },
                    "relationships": {
                        "tip": {
                            "data": {
                                "type": "versions",
                                "id": "1"
                            }
                        },
                        "parent": {
                            "data": {"type": "folders", "id": folder_id}
                        }
                    }
                },
                "included": [
                    {
                        "type": "versions",
                        "id": "1",
                        "attributes": {
                            "name": file_name,
                            "extension": {
                                "type": "versions:autodesk.bim360:File",
                                "version": "1.0"
                            }
                        },
                        "relationships": {
                            "storage": {
                                "data": {"type": "objects", "id": object_id}
                            }
                        }
                    }
                ]
            }
            item_resp = await client.post(item_url, headers=headers, json=item_payload)
            item_resp.raise_for_status()
            return item_resp.json()

    async def update_file_version(self, access_token: str, project_id: str, item_id: str, file_name: str, file_content: bytes) -> Dict[str, Any]:
        """Uploads a new version of an existing file (item) in Autodesk BIM."""
        import urllib.parse
        safe_project_id = urllib.parse.quote(project_id)
        safe_item_id = urllib.parse.quote(item_id, safe='')
        
        # 1. Create a storage location for the new version
        storage_url = f"{self.base_url}/data/v1/projects/{safe_project_id}/storage"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/vnd.api+json"
        }
        storage_payload = {
            "jsonapi": {"version": "1.0"},
            "data": {
                "type": "objects",
                "attributes": {
                    "name": file_name
                },
                "relationships": {
                    "target": {
                        "data": {"type": "items", "id": item_id}
                    }
                }
            }
        }
        async with httpx.AsyncClient() as client:
            storage_resp = await client.post(storage_url, headers=headers, json=storage_payload)
            storage_resp.raise_for_status()
            storage_data = storage_resp.json()
            object_id = storage_data["data"]["id"]
            
            # Extract bucketKey and objectName from object_id
            urn_parts = object_id.split(':')
            bucket_and_object = urn_parts[-1].split('/')
            bucket_key = bucket_and_object[0]
            object_key = '/'.join(bucket_and_object[1:])
            
            safe_object_key = urllib.parse.quote(object_key, safe='')
            
            # 2. Get signed S3 URL
            signed_url_endpoint = f"{self.base_url}/oss/v2/buckets/{bucket_key}/objects/{safe_object_key}/signeds3upload"
            signed_url_resp = await client.get(signed_url_endpoint, headers=headers)
            signed_url_resp.raise_for_status()
            signed_url_data = signed_url_resp.json()
            
            s3_upload_url = signed_url_data["urls"][0]
            upload_key = signed_url_data["uploadKey"]
            
            # 3. Upload exactly to the S3 URL (no Authorization header for AWS)
            s3_headers = {"Content-Type": "application/octet-stream"}
            s3_resp = await client.put(s3_upload_url, headers=s3_headers, content=file_content)
            s3_resp.raise_for_status()
            
            # 4. Finalize the upload
            finalize_payload = {"uploadKey": upload_key}
            finalize_headers = {
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json"
            }
            finalize_resp = await client.post(
                signed_url_endpoint,
                headers=finalize_headers,
                json=finalize_payload
            )
            finalize_resp.raise_for_status()
            
            # 5. Create the new Version for the existing Item
            version_url = f"{self.base_url}/data/v1/projects/{safe_project_id}/versions"
            version_payload = {
                "jsonapi": {"version": "1.0"},
                "data": {
                    "type": "versions",
                    "attributes": {
                        "name": file_name,
                        "extension": {
                            "type": "versions:autodesk.bim360:File",
                            "version": "1.0"
                        }
                    },
                    "relationships": {
                        "item": {
                            "data": {"type": "items", "id": item_id}
                        },
                        "storage": {
                            "data": {"type": "objects", "id": object_id}
                        }
                    }
                }
            }
            version_resp = await client.post(version_url, headers=headers, json=version_payload)
            version_resp.raise_for_status()
            return version_resp.json()


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

    async def delete_item(self, access_token: str, project_id: str, item_id: str):
        """Deletes (moves to trash) an item in Autodesk BIM 360 / ACC by posting a Deletion version."""
        import urllib.parse
        safe_project_id = urllib.parse.quote(project_id)
        url = f"{self.base_url}/data/v1/projects/{safe_project_id}/versions"
        
        payload = {
            "jsonapi": {"version": "1.0"},
            "data": {
                "type": "versions",
                "attributes": {
                    "extension": {
                        "type": "versions:autodesk.core:Deleted",
                        "version": "1.0"
                    }
                },
                "relationships": {
                    "item": {
                        "data": {
                            "type": "items",
                            "id": item_id
                        }
                    }
                }
            }
        }
        print(f"APS DELETE Item (Version) URL: {url}")
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/vnd.api+json"
        }
        async with httpx.AsyncClient() as client:
            response = await client.post(url, headers=headers, json=payload)
            print(f"APS DELETE Item Response: {response.status_code}")
            if response.status_code not in (200, 201, 204):
                print(f"APS DELETE Item Error Body: {response.text}")
            response.raise_for_status()
            return True

    async def delete_folder(self, access_token: str, project_id: str, folder_id: str):
        """Deletes (moves to trash) a folder in Autodesk BIM 360 / ACC by setting hidden to true."""
        import urllib.parse
        safe_project_id = urllib.parse.quote(project_id)
        safe_folder_id = urllib.parse.quote(folder_id, safe='')
        url = f"{self.base_url}/data/v1/projects/{safe_project_id}/folders/{safe_folder_id}"
        
        payload = {
            "jsonapi": {"version": "1.0"},
            "data": {
                "type": "folders",
                "id": folder_id,
                "attributes": {
                    "hidden": True
                }
            }
        }
        print(f"APS DELETE Folder (PATCH) URL: {url}")
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/vnd.api+json"
        }
        async with httpx.AsyncClient() as client:
            response = await client.patch(url, headers=headers, json=payload)
            print(f"APS DELETE Folder Response: {response.status_code}")
            if response.status_code not in (200, 204):
                print(f"APS DELETE Folder Error Body: {response.text}")
            response.raise_for_status()
            return True
