from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded
from sqlalchemy import text

# import app.models mainly so sqlalchemy registers them before create_all()
import app.models as models
from app.config import settings
from app.database import Base, engine, SessionLocal, col_id
from app.limiter import limiter
from app.auth import router as auth_router
from app.tickets import router as tickets_router
from app.audit import router as audit_router
from app.audit import log

app = FastAPI(
    title=settings.APP_NAME,
    description=settings.APP_DESCRIPTION,
    version=settings.APP_VERSION,
    debug=settings.DEBUG,
)

# specific handler for the RateLimitExceeded exception, thrown by slowapi
@app.exception_handler(RateLimitExceeded)
async def custom_rate_limit_handler(request: Request, exc: RateLimitExceeded):
    # log login failure to db
    db = SessionLocal()
    try:
        log(
            db=db,
            action="LOGIN_FAILED_SLOWAPI_LIMITER",
            resource="auth",
            ip_address=request.client.host if request.client else None
        )
    finally:
        db.close()

    return JSONResponse(
        status_code=429,
        content={"detail": f"Rate limit exceeded: {exc.detail}"}
    )

app.state.limiter = limiter
app.include_router(auth_router)
app.include_router(tickets_router)
app.include_router(audit_router)

# create db tables
Base.metadata.create_all(bind=engine)

@app.get("/health")
def health():
    # check db connectivity
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        db_status = "ok"
    except Exception as e:
        db_status = f"error: {e}"

    tables = list(engine.dialect.get_table_names(engine.connect()))

    return {
        "status": db_status,
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "debug": settings.DEBUG,
        "database": db_status,
        "tables": tables,
    }
