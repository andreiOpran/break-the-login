from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "AuthX"
    APP_DESCRIPTION: str = "Description"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    DATABASE_URL: str = "sqlite:///./authx.db"

    SECRET_KEY: str = "this-should-be-retrieved-from-env"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    class Config:
        env_file = ".env"


settings = Settings()
