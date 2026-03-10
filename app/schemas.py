from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr
from app.models import TicketSeverity, TicketStatus, UserRole


# AUTHENTICATION
class RegisterRequest(BaseModel):
    email: EmailStr
    password: str

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
