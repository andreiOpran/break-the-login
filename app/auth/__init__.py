from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from hashlib import md5
from passlib.context import CryptContext
from jose import jwt
from datetime import datetime, timezone, timedelta

from app.models import User, UserRole, PasswordResetToken, AuditLog
from app.schemas import (
    RegisterRequest, TokenResponse, LoginRequest, 
    ForgotPasswordRequest, ResetPasswordRequest
)
from app.database import get_db, col_id
from app.config import settings
from app.dependencies import get_current_user
from app.audit import log
from app.limiter import limiter, get_proxy_aware_ip_key, get_account_targeted_key


router = APIRouter(prefix="/auth", tags=["auth"])
password_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

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
        # FIXED VULNERABILITY 4.1 by implementing password format checker in app/schemas.py
        # VULNERABILITY 4.2 - INSECURE PASSWORD STORAGE (MD5, no salt)
        # FIXED VULNERABILITY 4.2 by migrating to bcrypt with salting
        password_hash = password_context.hash(body.password),
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
# Shield #1: Account Shield (1 IP, 1 email)
@limiter.limit(settings.SLOWAPI_AUTH_LIMIT, key_func=get_account_targeted_key)
# Shield #2: Global IP Shield (1 IP, many emails (will be triggered by 1 IP, 1 email also))
@limiter.limit(settings.SLOWAPI_IP_LIMIT, key_func=get_proxy_aware_ip_key) 
def login(body: LoginRequest, request: Request, db: Session = Depends(get_db)):
    # VULNERABILITY 4.3 - NO RATE LIMITING (unlimited login attempts)
    # FIXED VULNERABILITY 4.3 via triple shield limiter for various scenarios
    user = db.query(User).filter(User.email == body.email).first()
    
    # Shield #3: Inner Shield - check account lockout by the DB
    # catches ip rotation brute (many ips, 1 email attack)
    if settings.ENABLE_DB_LOCKOUT and user and bool(user.locked):
        # Check if ACCOUNT_LOCKOUT_MINUTES have passed since the last LOGIN_FAILED to unlock the account,
        # otherwise the account is still locked, return 429 and log "LOGIN_FAILED_LOCKED" in the audit
        last_fail = db.query(AuditLog).filter(
            AuditLog.user_id == user.id,
            AuditLog.action == "LOGIN_FAILED",
        ).order_by(AuditLog.timestamp.desc()).first()

        if last_fail:
            # sqlite strips timezone info, so we add it back for the comparison
            fail_time = last_fail.timestamp
            if fail_time.tzinfo is None:
                fail_time = fail_time.replace(tzinfo=timezone.utc)
            
            if bool(datetime.now(timezone.utc) - fail_time > timedelta(minutes=settings.ACCOUNT_LOCKOUT_MINUTES)):
                # ACCOUNT_LOCKOUT_MINUTES has passed, so we unlock the account
                setattr(user, "locked", False)
                db.commit()
            else:
                log(
                    db=db,
                    action="LOGIN_FAILED_LOCKED",
                    resource="auth",
                    user_id=col_id(user.id),
                    ip_address=request.client.host if request.client else None
                )
                # 429 Too Many Requests for standard rate-limiting
                raise HTTPException(status_code=429, detail="Account temporarily locked due to too many failed attempts")
        else:
            # fallback if no last_fail log is found, for the case where account is locked, 
            # and there are no logs to justify why; although it should not be possible
            raise HTTPException(status_code=429, detail="Account temporarily locked due to too many failed attempts")

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
    # verification is done in a try block to avoid crashing the app if we try to 
    # verify an old md5 token instead of the new bcrypt token
    try:
        password_is_valid = password_context.verify(body.password, stored_hash)
    except Exception:
        password_is_valid = False
        
    if not password_is_valid:
        log(
            db=db,
            action="LOGIN_FAILED",
            resource="auth",
            user_id=col_id(user.id),
            ip_address=request.client.host if request.client else None
        )

        # check for brute force IP rotation (many IPs, 1 email attack)
        failed_attempts = db.query(AuditLog).filter(
            AuditLog.user_id == user.id,
            AuditLog.action == "LOGIN_FAILED",
            AuditLog.timestamp >= datetime.now(timezone.utc) - timedelta(minutes=15)
        ).count()

        if failed_attempts >= settings.MAX_LOGIN_ATTEMPTS:
            setattr(user, "locked", True)
            db.commit()
            log(
                db=db,
                action="ACCOUNT_LOCKED",
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
    
    setattr(user, "password_hash", password_context.hash(body.new_password))
    db.commit()
    log(
        db=db,
        action="RESET_PASSWORD",
        resource="auth",
        user_id=col_id(reset_token.user_id),
        ip_address=request.client.host if request.client else None
    )
    return {"message": "Pasword reseted successfully"}
