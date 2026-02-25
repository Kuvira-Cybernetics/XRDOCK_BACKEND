from fastapi import Header, HTTPException, status
import firebase_admin
from firebase_admin import auth
from dotenv import load_dotenv

load_dotenv()

try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(options={'projectId': 'xrdock-app'})

import os

async def verify_firebase_token(authorization: str = Header(default=None)):
    # DEBUG BYPASS
    if os.getenv("DEBUG_SKIP_AUTH") == "true":
        return {"uid": "debug_user", "email": "debug@example.com"}

    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header is required",
        )
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials. Must start with 'Bearer '",
        )
    
    token = authorization.split("Bearer ")[1]
    
    try:
        decoded_token = auth.verify_id_token(token)
        uid = decoded_token.get('uid')
        email = decoded_token.get('email')
        return {"uid": uid, "email": email}
    except Exception as e:
        print(f"Firebase verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}"
        )
