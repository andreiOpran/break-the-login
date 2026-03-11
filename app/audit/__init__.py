from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.models import AuditLog, User, UserRole
from app.schemas import AuditLogOut
from app.database import get_db
from app.auth import get_current_user


router = APIRouter(prefix="/audit", tags=["audit"])

def log(
    db: Session,
    action: str,
    resource: str,
    user_id: int | None = None, # is none in cases of failed login for non-existent user
    resource_id: str | None = None,
    ip_address: str | None = None,
):
    entry = AuditLog(
        user_id=user_id,
        action=action,
        resource=resource,
        resource_id=resource_id,
        ip_address=ip_address,
    )
    db.add(entry)
    db.commit()
    

@router.get("/", response_model=list[AuditLogOut])
def read_logs(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if str(current_user.role) != UserRole.MANAGER:
        raise HTTPException(status_code=403, detail="Access denied: only MANAGERS can read logs")
    
    return db.query(AuditLog).order_by(AuditLog.timestamp.desc()).all()
