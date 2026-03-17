from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "AuthX"
    APP_DESCRIPTION: str = "Description"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    DATABASE_URL: str = "sqlite:///./authx.db"

    SECRET_KEY: str = "this-should-be-retrieved-from-env"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_HOURS: int = 168
    
    # SLOWAPI LIMITER
    # specific to account (1 ip, 1 email)
    SLOWAPI_AUTH_LIMIT: str = "3/1 minute"
    # global shield, blocks an IP after 20 attempts targeting ANY emails (prevents DoS)
    # has higher limit, but still could cause "Collateral Damage"
    # where innocent users sharing an IP get blocked
    SLOWAPI_IP_LIMIT: str = "20/1 minute"
    # set to true to allow spoofing "X-Forwarded-For" and bypassing both limiters
    TRUST_PROXY_HEADERS: bool = True
    # set to True to block the entire IP after 5 fails and basically convert Shield #1 to Shield #2,
    # and cause "Collateral Damage" much earlier
    # set to False to only block the specific ip + email combination, and to work as intended
    USE_IP_ONLY_LIMITER: bool = False
    
    # DB ACCOUNT LOCKOUT
    ENABLE_DB_LOCKOUT: bool = True  # Inner Shield, blocks many IPs targeting one email by locking the account in DB
    ACCOUNT_LOCKOUT_MINUTES: int = 1
    MAX_LOGIN_ATTEMPTS: int = 5

    class Config:
        env_file = ".env"


settings = Settings()
