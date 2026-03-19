from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.dependencies import get_current_user
from app.schemas import TicketOut, TicketCreate, TicketUpdate
from app.database import get_db, col_id
from app.models import User, Ticket, UserRole
from app.audit import log


router = APIRouter(prefix="/tickets", tags=["tickets"])

@router.post("/", response_model=TicketOut, status_code=201)
def create_ticket(
    body: TicketCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ticket = Ticket(
        title=body.title,
        description=body.description,
        severity=body.severity,
        owner_id=current_user.id,
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)  # so that ticket.id can be populated from the db
    log(
        db=db,
        action="CREATE_TICKET",
        resource="ticket",
        user_id=col_id(current_user.id),
        resource_id=str(ticket.id),
        ip_address=request.client.host if request.client else None
    )
    return ticket

@router.get("/", response_model=list[TicketOut])
def read_tickets(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
):
    return db.query(Ticket).filter(Ticket.owner_id == current_user.id).all()

@router.get("/{ticket_id}", response_model=TicketOut)
def get_ticket(
    ticket_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user) # auth required
):
    # VULNERABILITY IDOR: no ownership check, ticket can be retrieved by anyone
    # FIXED VULNERABILITY IDOR: added ownership check
    ticket = db.query(Ticket).filter(Ticket.id == ticket_id, Ticket.owner_id == current_user.id).first()
    if ticket is None:
        raise HTTPException(status_code=404, detail="Ticket not found")

    log(
        db=db,
        action="GET_TICKET",
        resource="ticket",
        user_id=col_id(current_user.id),
        resource_id=str(ticket_id),
        ip_address=request.client.host if request.client else None
    )
    return ticket

@router.patch("/{ticket_id}", response_model=TicketOut)
def update_ticket(
    ticket_id: int,
    body: TicketUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user) # auth required
):
    # VULNERABILITY IDOR: no ownership check, ticket can be updated by anyone
    # FIXED VULNERABILITY IDOR: added ownership check
    ticket = db.query(Ticket).filter(Ticket.id == ticket_id, Ticket.owner_id == current_user.id).first()
    if ticket is None:
        raise HTTPException(status_code=404, detail="Ticket not found")
        
    update_data = body.model_dump(exclude_unset=True)
    
    # VULNERABILITY RBAC: analysts can change ticket status
    # FIXED VULNERABILITY RBAC: only managers can update ticket status
    if bool("status" in update_data and current_user.role != UserRole.MANAGER):
        log(
            db=db,
            action="UPDATE_TICKET_STATUS_FAILED_RBAC",
            resource="ticket",
            user_id=col_id(current_user.id),
            resource_id=str(ticket.id),
            ip_address=request.client.host if request.client else None
        )
        raise HTTPException(status_code=403, detail="Not authorized to change ticket status")
    
    for field, value in update_data.items():
        setattr(ticket, field, value)
    db.commit()
    db.refresh(ticket) # so that ticket.updated_at can be updated in the db
    log(
        db=db,
        action="UPDATE_TICKET",
        resource="ticket",
        user_id=col_id(current_user.id),
        resource_id=str(ticket.id),
        ip_address=request.client.host if request.client else None
    )
    return ticket

@router.delete("/{ticket_id}", status_code=204)
def delete_ticket(
    ticket_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user) # auth required
):
    # VULNERABILITY IDOR: no ownership check, ticket can be deleted by anyone
    # FIXED VULNERABILITY IDOR: added ownership check
    ticket = db.query(Ticket).filter(Ticket.id == ticket_id, Ticket.owner_id == current_user.id).first()
    if ticket is None:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    db.delete(ticket)
    db.commit()
    log(
        db=db,
        action="DELETE_TICKET",
        resource="ticket",
        user_id=col_id(current_user.id),
        resource_id=str(ticket_id),
        ip_address=request.client.host if request.client else None
    )
