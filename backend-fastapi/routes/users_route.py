
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from utils.supabase.auth import jwt_middleware, register_middleware
from utils.supabase.supabase import supabaseAdmin

router = APIRouter()

class UserRegister(BaseModel):
    email: str
    password: str
    name: str

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register_user(
    user: UserRegister,
    data=Depends(register_middleware)
):
    try:
        print(data)
        print(user)
        register_data = {
            "email": user.email,
            "password": user.password,
            "email_confirm": True,
            "app_metadata": {"role": data["role"]},
            "user_metadata": {"name": user.name}
        }
        response = supabaseAdmin.auth.admin.create_user(register_data)
        
        # Supabase auth admin responses have a 'user' attribute on success
        if hasattr(response, 'user') and response.user:
            return {"message": "User registered successfully", "user": response.user}
        else:
            print(response)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create user: No user data returned from Supabase"
            )
    except Exception as e:
        print(e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unexpected error: {str(e)}"
        )


@router.get("/list", status_code=status.HTTP_200_OK)
async def list_users(
    user=Depends(jwt_middleware)
):
    if user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view users.",
        )

    try:
            response = supabaseAdmin.auth.admin.list_users()
            users = []
            # Supabase may return users in response.users or as a list
            if hasattr(response, 'users'):
                raw_users = response.users
            elif isinstance(response, list):
                raw_users = response
            else:
                raw_users = []

            for usr in raw_users:
                # Convert to dict if possible
                if hasattr(usr, 'to_dict'):
                    user_dict = usr.to_dict()
                elif isinstance(usr, dict):
                    user_dict = usr
                else:
                    user_dict = dict(usr)
                # Set role from app_metadata
                app_metadata = user_dict.get('app_metadata', {})
                user_dict['role'] = app_metadata.get('role', 'user')
                users.append(user_dict)
                print(user_dict)
            return {"users": users}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error fetching users: {str(e)}"
        )
@router.delete("/delete/{user_id}", status_code=status.HTTP_200_OK)
async def delete_user(
    user_id: str,
    user=Depends(jwt_middleware)
):
    if user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to delete users.",
        )

    try:
        response = supabaseAdmin.auth.admin.delete_user(user_id)
        
        # Delete operations may return None or a success indicator
        return {"message": "User deleted successfully"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error deleting user: {str(e)}"
        )