from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from hashlib import md5
from jose import jwt
from datetime import datetime, timezone, timedelta

from app.models import User, UserRole, PasswordResetToken
from app.schemas import (
    RegisterRequest, TokenResponse, LoginRequest, 
    ForgotPasswordRequest, ResetPasswordRequest
)
from app.database import get_db, col_id
from app.config import settings
from app.dependencies import get_current_user
from app.audit import log


router = APIRouter(prefix="/auth", tags=["auth"])

# "Depends" calls get_db() (getting what get_db() yields)
# so it opens and closes a session during the request
@router.post("/register", status_code=201)
def register(body: RegisterRequest, request: Request, db: Session = Depends(get_db)):
    # VULNERABILITY 4.4 - USER ENUMERATION, DIFFERENT MESSAGES FOR EXISTING/NON-EXISTING EMAIL
    existing = db.query(User).filter(User.email == body.email).first()
    if existing:
        log(
            db=db,
            action="REGISTER_FAILED",
            resource="auth",
            ip_address=request.client.host if request.client else None
        )
        raise HTTPException(status_code=400, detail="There is already an account with this email")
    
    user = User(
        email=body.email,
        # VULNERABILITY 4.1 - WEAK PASSWORD POLICY (no length/complexity check)
        # VULNERABILITY 4.2 - INSECURE PASSWORD STORAGE (MD5, no salt)
        password_hash = md5(body.password.encode()).hexdigest(),
        role=UserRole.ANALYST
    )
    db.add(user)
    db.commit()
    db.refresh(user)  # so that user.id can be populated from the db
    log(
        db=db,
        action="REGISTER",
        resource="auth",
        user_id=col_id(user.id),
        ip_address=request.client.host if request.client else None
    )
    return {"message": "User registered successfully", "id": user.id}

@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, request: Request, db: Session = Depends(get_db)):
    # VULNERABILITY 4.3 - NO RATE LIMITING (unlimited login attempts)
    user = db.query(User).filter(User.email == body.email).first()
    
    # VULNERABILITY 4.4 - USER ENUMERATION, DIFFERENT MESSAGES FOR INVALID USER/PASS
    if not user:
        log(
            db=db,
            action="LOGIN_FAILED",
            resource="auth",
            ip_address=request.client.host if request.client else None
        )
        raise HTTPException(status_code=401, detail="User not found")
    
    stored_hash: str = str(user.password_hash) # aux var to avoid type check error
    if stored_hash != md5(body.password.encode()).hexdigest():
        log(
            db=db,
            action="LOGIN_FAILED",
            resource="auth",
            user_id=col_id(user.id),
            ip_address=request.client.host if request.client else None
        )
        raise HTTPException(status_code=401, detail="Wrong password")
    
    # VULNERABILITY 4.5 - weak secret, 1w expiry, no rotation
    payload = {
        "sub": str(user.id),
        "email": user.email,
        "role": user.role.value,
        "exp": datetime.now(timezone.utc) + timedelta(hours=settings.ACCESS_TOKEN_EXPIRE_HOURS),
    }
    # strucure of jwt: header.payload.signature
    # (header is the algo used + "jwt"; payload points to who owns it; 
    # signature is made using SECRET_KEY)
    token = jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    log(
        db=db,
        action="LOGIN",
        resource="auth",
        user_id=col_id(user.id),
        ip_address=request.client.host if request.client else None
    )
    return TokenResponse(access_token=token)

# VULNERABILITY 4.5 - token remains available after log out,
# until its expiry, and can still be used if an attacker captures it
@router.post("/logout")
def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    log(
        db=db,
        action="LOGOUT",
        resource="auth",
        user_id=col_id(current_user.id),
        ip_address=request.client.host if request.client else None
    )
    return {"message": "Log out successful"}

# VULNERABILITY 4.6 - INSECURE PASSWORD RESET 
# (token is md5 encryption of the email, making it predictable;
# token is always the same and can be reused; token does not have expiry)
@router.post("/forgot-password")
def forgot_password(
    body: ForgotPasswordRequest,
    request: Request,
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.email == body.email).first()
    if not user:
        log(
            db=db,
            action="FORGOT_PASSWORD_FAILED",
            resource="auth",
            ip_address=request.client.host if request.client else None
        )
        raise HTTPException(status_code=404, detail="Email not found")

    # if the attacker knows the email, they can recreate the token
    token = md5(body.email.encode()).hexdigest()
    
    existing_token = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == token,
        PasswordResetToken.user_id == user.id
    ).first()
    
    if not existing_token:
        # only add a token if we did not found any in the db,
        # to avoid unique constraint error
        reset_token = PasswordResetToken(user_id=user.id, token=token)
        db.add(reset_token)
        db.commit()
        log(
            db=db,
            action="FORGOT_PASSWORD",
            resource="auth", user_id=col_id(user.id),
            ip_address=request.client.host if request.client else None
        )
    else:
        log(
            db=db,
            action="FORGOT_PASSWORD",
            resource="auth", user_id=col_id(user.id),
            ip_address=request.client.host if request.client else None
        )
    
    return {"reset_token": token}

@router.post("/reset-password")
def reset_password(
    body: ResetPasswordRequest,
    request: Request,
    db: Session = Depends(get_db)
):
    reset_token = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == body.token
    ).first()
    
    if not reset_token:
        log(
            db=db,
            action="RESET_PASSWORD_FAILED",
            resource="auth", ip_address=request.client.host if request.client else None
        )
        raise HTTPException(status_code=400, detail="Invalid token")
    
    user = db.get(User, reset_token.user_id)
    if user is None:
        raise HTTPException(status_code=400, detail="User not found")
    
    setattr(user, "password_hash", md5(body.new_password.encode()).hexdigest())
    db.commit()
    log(
        db=db,
        action="RESET_PASSWORD",
        resource="auth",
        user_id=col_id(reset_token.user_id),
        ip_address=request.client.host if request.client else None
    )
    return {"message": "Pasword reseted successfully"}
