from slowapi import Limiter
from slowapi.util import get_remote_address
from fastapi import Request
import json
from app.config import settings

def get_proxy_aware_ip_key(request: Request):
    """
    Returns IP, respects proxy headers only if TRUST_PROXY_HEADERS is true
    Used for the Global IP Shield (Shield #2)
    """
    ip = get_remote_address(request)
    if settings.TRUST_PROXY_HEADERS:
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            ip = forwarded_for.split(",")[0].strip()
    return ip

def get_account_targeted_key(request: Request):
    """
    Login key consists of ip + email
    Catches traditional brute force (1 ip, 1 email)
    Used for the Account Shield (Shield #1)
    """
    ip = get_proxy_aware_ip_key(request)
    
    # if the flag is set, only use the IP for the key
    if settings.USE_IP_ONLY_LIMITER:
        return ip
    
    # check if the body has already been read/cached by fastapi,
    # to prevent "RuntimeWarning: coroutine was never awaited" 
    # and "body already consumed"
    try:
        # access internal broadcast_body if it was already read
        body_bytes = getattr(request, "_body", None)
        if body_bytes:
            body = json.loads(body_bytes)
            return f"{ip}:{body.get('email', 'unknown')}"
    except Exception:
        pass

    return ip

limiter = Limiter(key_func=get_account_targeted_key)
