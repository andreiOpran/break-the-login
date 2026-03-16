from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, field_validator
from app.models import TicketSeverity, TicketStatus, UserRole
from re import search

# AUTHENTICATION
def validate_password_complexity(password: str) -> str:
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters long")
    if not search(r"[A-Z]", password):
        raise ValueError("Password must contain at least one uppercase letter")
    if not search(r"[a-z]", password):
        raise ValueError("Password must contain at least one lowercase letter")
    if not search(r"\d", password):
        raise ValueError("Password must contain at least one digit")
    if not search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        raise ValueError("Password must contain at least one special character")
    return password

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator("password")
    def validate_password(cls, v):
        return validate_password_complexity(v)

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    def validate_password(cls, v):
        return validate_password_complexity(v)

# USER
class UserOut(BaseModel):
    id: int
    email: str
    role: UserRole
    created_at: datetime
    locked: bool

    # set pydantic to read objects (sqlalchemy return), not just plain dicts
    model_config = {"from_attributes": True}

# TICKETS
class TicketCreate(BaseModel):
    title: str
    description: str
    severity: TicketSeverity = TicketSeverity.LOW

class TicketUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    severity: Optional[TicketSeverity] = None
    status: Optional[TicketStatus] = None

class TicketOut(BaseModel):
    id: int
    title: str
    description: str
    severity: TicketSeverity
    status: TicketStatus
    owner_id: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

# AUDIT
class AuditLogOut(BaseModel):
    id: int
    user_id: Optional[int]
    action: str
    resource: str
    resource_id: Optional[str]
    timestamp: datetime
    ip_address: Optional[str]

    model_config = {"from_attributes": True}
