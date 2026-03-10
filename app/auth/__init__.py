from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from hashlib import md5

from app.models import User, UserRole
from app.schemas import RegisterRequest
from app.database import get_db

router = APIRouter(prefix="/auth", tags=["auth"])

# "Depends" calls get_db() (getting what get_db() yields)
# so it opens and closes a session during the request
@router.post("/register", status_code=201)
def register(request: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == request.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="There is already an account with this email")
    
    user = User(
        email=request.email,
        # VULNERABILITY 4.2 - WEAK PASSWORD POLICY (MD5, NO SALT)
        password_hash = md5(request.password.encode()).hexdigest(),
        role=UserRole.ANALYST
    )
    db.add(user)
    db.commit()
    db.refresh(user)  # so that user.id can be populated from the db
    return {"message": "User registered successfully", "id": user.id}
