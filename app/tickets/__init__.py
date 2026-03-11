from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.schemas import TicketOut, TicketCreate, TicketUpdate
from app.database import get_db, col_id
from app.models import User, Ticket
from app.audit import log


router = APIRouter(prefix="/tickets", tags=["tickets"])

@router.post("/", response_model=TicketOut, status_code=201)
def create_ticket(
    request: TicketCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ticket = Ticket(
        title=request.title,
        description=request.description,
        severity=request.severity,
        owner_id=current_user.id,
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)  # so that ticket.id can be populated from the db
    log(db, action="CREATE_TICKET", resource="ticket", user_id=col_id(current_user.id), resource_id=str(ticket.id))
    return ticket

@router.get("/", response_model=list[TicketOut])
def read_tickets(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
):
    return db.query(Ticket).filter(Ticket.owner_id == current_user.id).all()

@router.get("/{ticket_id}", response_model=TicketOut)
def get_ticket(
    ticket_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user) # auth required
):
    # VULNERABILITY IDOR: no ownership check, ticket can be retrieved by anyone
    ticket = db.get(Ticket, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    return ticket

@router.patch("/{ticket_id}", response_model=TicketOut)
def update_ticket(
    ticket_id: int,
    request: TicketUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user) # auth required
):
    ticket = db.get(Ticket, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    # VULNERABILITY IDOR: no ownership check, ticket can be updated by anyone
    for field, value in request.model_dump(exclude_unset=True).items():
        setattr(ticket, field, value)
    db.commit()
    db.refresh(ticket) # so that ticket.updated_at can be updated in the db
    log(db, action="UPDATE_TICKET", resource="ticket", user_id=col_id(current_user.id), resource_id=str(ticket.id))
    return ticket

@router.delete("/{ticket_id}", status_code=204)
def delete_ticket(
    ticket_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user) # auth required
):
    # VULNERABILITY IDOR: no ownership check, ticket can be deleted by anyone
    ticket = db.get(Ticket, ticket_id)
    if ticket is None:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    db.delete(ticket)
    db.commit()
    log(db, action="DELETE_TICKET", resource="ticket", user_id=col_id(current_user.id), resource_id=str(ticket_id))
