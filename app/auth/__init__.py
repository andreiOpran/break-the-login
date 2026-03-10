from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from hashlib import md5
from jose import jwt, JWTError
from datetime import datetime, timezone, timedelta

from app.models import User, UserRole
from app.schemas import RegisterRequest, TokenResponse, LoginRequest
from app.database import get_db
from app.config import settings


router = APIRouter(prefix="/auth", tags=["auth"])

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
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    user=db.get(User, int(user_id))
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user

# "Depends" calls get_db() (getting what get_db() yields)
# so it opens and closes a session during the request
@router.post("/register", status_code=201)
def register(request: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == request.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="There is already an account with this email")
    
    user = User(
        email=request.email,
        # VULNERABILITY 4.1 - WEAK PASSWORD POLICY (no length/complexity check)
        # VULNERABILITY 4.2 - INSECURE PASSWORD STORAGE (MD5, NO SALT)
        password_hash = md5(request.password.encode()).hexdigest(),
        role=UserRole.ANALYST
    )
    db.add(user)
    db.commit()
    db.refresh(user)  # so that user.id can be populated from the db
    return {"message": "User registered successfully", "id": user.id}

@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == request.email).first()
    
    # VULNERABILITY 4.4 - USER ENUMERATION, DIFFERENT MESSAGES FOR INVALID USER/PASS
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    
    stored_hash: str = str(user.password_hash) # aux var to avoid type check error
    if stored_hash != md5(request.password.encode()).hexdigest():
        raise HTTPException(status_code=401, detail="Wrong password")
    
    # VULNERABILITY 4.5 - weak secret, 1w expiry, no rotation
    payload = {
        "sub": str(user.id),
        "email": user.email,
        "role": user.role.value,
        "exp": datetime.now(timezone.utc) + timedelta(hours=settings.ACCESS_TOKEN_EXPIRE_HOURS),
    }
    # strucure of jwt: header.payload.signature
    # (header is the algo used + "jwt"; payload points to who owns it; signature is made using SECRET_KEY)
    token = jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return TokenResponse(access_token=token)

# VULNERABILITY 4.5 - token remains available after log out,
# until its expiry, and can still be used if an attacker captures it
@router.post("/logout")
def logout(user: User = Depends(get_current_user)):
    return {"message": "Log out successful"}

