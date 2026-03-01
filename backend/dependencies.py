from fastapi import Header, HTTPException, status
import firebase_admin
from firebase_admin import auth, credentials
import os
import jwt
from dotenv import load_dotenv

load_dotenv()

try:
    firebase_admin.get_app()
except ValueError:
    if os.path.exists("serviceAccountKey.json"):
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    else:
        print("Warning: serviceAccountKey.json not found. Falling back to default app initialization.")
        firebase_admin.initialize_app(options={'projectId': 'xrdock-app'})

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
    
    # 1. Try Firebase ID Token (Standard)
    try:
        decoded_token = auth.verify_id_token(token)
        return {"uid": decoded_token.get('uid'), "email": decoded_token.get('email')}
    except Exception:
        # 2. Fallback: Try Symmetric session token (for Unity)
        try:
            # We use HS256 with a simple secret for Unity sessions to bypass ID token requirements
            secret = os.getenv("JWT_SECRET", "xrdock_secret_key_2024")
            decoded = jwt.decode(token, secret, algorithms=["HS256"])
            return {"uid": decoded.get("uid"), "email": decoded.get("email")}
        except Exception as e:
            print(f"Auth failed (Firebase & Symmetric): {e}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token (neither valid Firebase ID nor session token)"
            )
