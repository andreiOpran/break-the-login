from fastapi import FastAPI
from app.config import settings
from app.database import Base, engine
from sqlalchemy import text
import app.models  # imported so sqlalchemy registers them before create_all()

from app.auth import router as auth_router
from app.tickets import router as tickets_router

app = FastAPI(
    title=settings.APP_NAME,
    description=settings.APP_DESCRIPTION,
    version=settings.APP_VERSION,
    debug=settings.DEBUG,
)

app.include_router(auth_router)
app.include_router(tickets_router)

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
