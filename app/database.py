from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from app.config import settings

# low level connection
engine = create_engine(settings.DATABASE_URL)

# tracks db operations
# autocommit=False - we will call db.commit() to save changes
# autoflush=False - sqlalchemy won't autosend pending changes to db before every query
# bind=engine - link session to engine
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# all models inherit this, to map Py classes to db tables
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        # we yield instead of return, so that we can do the cleanup
        yield db 
    finally:
        db.close()
        
# silencer helper for int(Column[int]) pylance incompatibility errors
def col_id(col: object) -> int:
    return int(col) # type: ignore[arg-type]
