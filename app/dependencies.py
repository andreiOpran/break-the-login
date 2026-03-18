from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import jwt, JWTError

from app.models import User
from app.database import get_db
from app.config import settings


bearer_scheme = HTTPBearer()

# dependency that reads Bearer token from header, verifies it, then returns matching user
# if there is any mismatch, the request recieves 401 before the route runs
def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme), 
    db: Session = Depends(get_db)
) -> User:
    token = credentials.credentials  # raw jwt string
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str | None = payload.get("sub")
        token_version: int | None = payload.get("token_version")
        if user_id is None or token_version is None:
            raise HTTPException(status_code=401, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    user=db.get(User, int(user_id))
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    
    # rotation security check, match the request token version to user current version from the DB
    if bool(user.token_version != token_version):
        raise HTTPException(status_code=401, detail="Session expired due to new login")
    
    return user