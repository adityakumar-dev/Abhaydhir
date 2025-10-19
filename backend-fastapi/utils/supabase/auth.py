import os
import jwt
from fastapi import Request, HTTPException, status, Depends
from utils.supabase.supabase import supabaseAdmin

# Load environment variables
LEGACY_JWT_SECRET = os.getenv("LEGACY_JWT_SECRET")
REGISTER_SECURITY_KEY = os.getenv("REGISTER_SECURITY_KEY")
REGISTER_ADMIN_KEY = os.getenv("REGISTER_ADMIN_KEY")

# -------------------------------------------------------------------
# JWT Middleware
# -------------------------------------------------------------------
async def jwt_middleware(request: Request) -> dict:
    """Dependency to verify JWT token from Authorization header."""
    auth_header = request.headers.get("Authorization")
    print("Token is : ", auth_header)
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = auth_header.split(" ", 1)[1]

    try:
        payload = jwt.decode(token, LEGACY_JWT_SECRET, algorithms=["HS256"],  options={"verify_aud": False})
        print(payload)
        payload['role'] = payload['app_metadata']['role']
        return payload
    except jwt.ExpiredSignatureError:
        print("Token has expired")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError:
        print("Invalid token")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )

# -------------------------------------------------------------------
# Register API Key Middleware (for device registration, guard/admin tools)
# -------------------------------------------------------------------
async def register_middleware(request: Request) -> dict:
    """Dependency to verify custom x-api-key header for registration flows."""
    auth_header = request.headers.get("x-api-key")
    print(auth_header)
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid x-api-key header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = auth_header.split(" ", 1)[1]
    if token == REGISTER_SECURITY_KEY:
        return {"role": "security"}
    elif token == REGISTER_ADMIN_KEY:
        return {"role": "admin"}
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )

# -------------------------------------------------------------------
# Guard/Admin Access Check
# -------------------------------------------------------------------
async def check_guard_admin_access(
    payload: dict = Depends(jwt_middleware), 
    request: Request = None
):
    """Dependency to verify if the authenticated user is guard/admin AND allowed for the event."""
    role = payload.get("role")
    uid = payload.get("sub") or payload.get("uid")

    if role not in ["admin", "security"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access this resource.",
        )

    # Parse body to get event_id (assuming JSON body)
    event_id = None
    if request:
        event_id = request.path_params.get("event_id")
        if not event_id:
            event_id = request.query_params.get("event_id")
    # also try with json 
    if event_id == None :
        # try with json find 
        json_data = await request.json()
        print(json_data)
        event_id = json_data.get("event_id")

   

    if not event_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing event_id in request body",
        )

    response = supabaseAdmin.table("events").select("allowed_guards").eq("event_id", event_id).single().execute()
   
    if hasattr(response, 'error') :
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found or Supabase error.",
        )

    allowed_guards = response.data.get("allowed_guards") or []
    print("Allowed guards are : ", allowed_guards)
    print("Role is : ", role)
    print("table data is : ", response.data)

    if allowed_guards == [] :
        return payload
    
    if allowed_guards is not None:
        if (role == "security" and uid not in allowed_guards) :
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not authorized to access this event.",
            )

    return payload
