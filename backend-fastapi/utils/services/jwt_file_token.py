"""
JWT Token Generator and Verifier for Secure File Access
This module provides utilities to generate and verify JWT tokens for secure file access
"""
import jwt
import os
from datetime import datetime, timedelta
from typing import Optional, Dict

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-this")

def generate_file_token(
    file_path: str, 
    token_type: str = "file_access",
    expires_in: int = 86400 * 30,
    additional_data: Optional[Dict] = None
) -> str:
    """
    Generate a JWT token for secure file access
    
    Args:
        file_path: The file path to encode in the token
        token_type: Type of token (visitor_card, user_image, etc.)
        expires_in: Token expiry time in seconds (default: 30 days)
        additional_data: Optional dictionary with additional data to include in token
    
    Returns:
        JWT token string
    
    Example:
        token = generate_file_token("static/uploads/user_123.jpg", "user_image")
    """
    payload = {
        "file_path": file_path,
        "exp": datetime.utcnow() + timedelta(seconds=expires_in),
        "iat": datetime.utcnow(),
        "type": token_type
    }
    
    # Add any additional data to the payload
    if additional_data:
        payload.update(additional_data)
    
    token = jwt.encode(payload, SECRET_KEY, algorithm="HS256")
    return token


def verify_file_token(
    token: str, 
    expected_type: Optional[str] = None
) -> Dict:
    """
    Verify and decode a JWT token for file access
    
    Args:
        token: The JWT token to verify
        expected_type: Expected token type (if None, any type is accepted)
    
    Returns:
        Decoded payload dictionary containing file_path and other data
    
    Raises:
        jwt.ExpiredSignatureError: If token has expired
        jwt.InvalidTokenError: If token is invalid
        ValueError: If token type doesn't match expected type
    
    Example:
        payload = verify_file_token(token, "user_image")
        file_path = payload["file_path"]
    """
    # Decode and verify JWT token
    payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
    
    # Verify token type if expected_type is provided
    if expected_type and payload.get("type") != expected_type:
        raise ValueError(f"Invalid token type. Expected '{expected_type}', got '{payload.get('type')}'")
    
    return payload


def validate_file_path_security(file_path: str, allowed_dirs: list) -> bool:
    """
    Validate that a file path is within allowed directories
    
    Args:
        file_path: The file path to validate
        allowed_dirs: List of allowed directory paths
    
    Returns:
        True if file path is within allowed directories, False otherwise
    
    Example:
        is_valid = validate_file_path_security(
            "static/uploads/user_123.jpg",
            ["static/uploads", "static/cards"]
        )
    """
    abs_file_path = os.path.abspath(file_path)
    allowed_abs_dirs = [os.path.abspath(dir) for dir in allowed_dirs]
    
    return any(abs_file_path.startswith(allowed_dir) for allowed_dir in allowed_abs_dirs)


def generate_visitor_card_token(file_path: str, expires_in: int = 86400 * 30) -> str:
    """
    Generate a JWT token for visitor card access
    (Convenience wrapper for backward compatibility)
    
    Args:
        file_path: Path to the visitor card file
        expires_in: Token expiry time in seconds (default: 30 days)
    
    Returns:
        JWT token string
    """
    return generate_file_token(file_path, token_type="visitor_card", expires_in=expires_in)


def generate_user_image_token(file_path: str, user_id: int, expires_in: int = 86400 * 30) -> str:
    """
    Generate a JWT token for user image access
    
    Args:
        file_path: Path to the user image file
        user_id: User ID associated with the image
        expires_in: Token expiry time in seconds (default: 30 days)
    
    Returns:
        JWT token string
    """
    return generate_file_token(
        file_path, 
        token_type="user_image", 
        expires_in=expires_in,
        additional_data={"user_id": user_id}
    )
