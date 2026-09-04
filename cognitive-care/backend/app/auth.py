import os

from datetime import datetime, timedelta, timezone

import bcrypt
from jose import JWTError, jwt

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

from dotenv import load_dotenv

from .database import revoked_tokens_collection


load_dotenv()

SECRET_KEY = os.getenv("JWT_SECRET_KEY")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24

if not SECRET_KEY:
    raise ValueError("JWT_SECRET_KEY is not set in .env")


# FastAPI will read:
# Authorization: Bearer <token>
oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/auth/login",
    
)


def hash_password(password: str) -> str:
    password_bytes = password.encode("utf-8")

    if len(password_bytes) > 72:
        raise ValueError("Password must be 72 bytes or fewer")

    return bcrypt.hashpw(
        password_bytes,
        bcrypt.gensalt()
    ).decode("utf-8")


def verify_password(
    plain_password: str,
    hashed_password: str
) -> bool:
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8"),
        )
    except (ValueError, TypeError):
        return False


def create_access_token(
    user_id: str,
    role: str
):
    now = datetime.now(timezone.utc)

    expire = now + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        "sub": str(user_id),
        "role": role,
        "iat": now,
        "exp": expire,
    }

    return jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM,
    )


def get_current_user(
    token: str = Depends(oauth2_scheme)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired authentication token",
        headers={
            "WWW-Authenticate": "Bearer"
        },
    )

    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
        )

        user_id = payload.get("sub")
        role = payload.get("role")

        if user_id is None or role is None:
            raise credentials_exception

        revoked = revoked_tokens_collection.find_one(
            {"token": token}
        )

        if revoked:
            raise credentials_exception

        return {
            "user_id": str(user_id),
            "role": role,
        }

    except JWTError:
        raise credentials_exception

def revoke_token(token: str) -> None:
    """
    Store the JWT as revoked until its natural expiration.
    """

    try:
        claims = jwt.get_unverified_claims(token)

        expires_at = datetime.fromtimestamp(
            claims["exp"],
            timezone.utc,
        )

    except (
        JWTError,
        KeyError,
        TypeError,
        ValueError,
    ):
        return

    revoked_tokens_collection.update_one(
        {"token": token},
        {
            "$setOnInsert": {
                "token": token,
                "expires_at": expires_at,
            }
        },
        upsert=True,
    )


def require_role(required_role: str):

    def role_checker(
        current_user=Depends(get_current_user)
    ):

        if current_user["role"] != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )

        return current_user

    return role_checker