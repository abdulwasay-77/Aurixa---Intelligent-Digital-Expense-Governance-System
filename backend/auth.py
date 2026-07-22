import jwt
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
import bcrypt
from config import config


class AuthManager:
    def __init__(self):
        self.secret_key = config.JWT_SECRET
        self.algorithm = config.JWT_ALGORITHM
        self.access_expire_minutes = config.JWT_ACCESS_EXPIRE_MINUTES
        self.refresh_expire_days = config.JWT_REFRESH_EXPIRE_DAYS
    
    def hash_password(self, password: str) -> str:
        password_bytes = password.encode('utf-8')[:72]
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(password_bytes, salt)
        return hashed.decode('utf-8')
    
    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        plain_bytes = plain_password.encode('utf-8')[:72]
        hashed_bytes = hashed_password.encode('utf-8')
        return bcrypt.checkpw(plain_bytes, hashed_bytes)
    
    def create_access_token(self, user_id: int, email: str) -> str:
        expire = datetime.now(timezone.utc) + timedelta(minutes=self.access_expire_minutes)
        payload = {
            "sub": str(user_id),
            "email": email,
            "type": "access",
            "exp": expire,
            "iat": datetime.now(timezone.utc)
        }
        return jwt.encode(payload, self.secret_key, algorithm=self.algorithm)
    
    def create_refresh_token(self, user_id: int, email: str) -> str:
        expire = datetime.now(timezone.utc) + timedelta(days=self.refresh_expire_days)
        payload = {
            "sub": str(user_id),
            "email": email,
            "type": "refresh",
            "exp": expire,
            "iat": datetime.now(timezone.utc)
        }
        return jwt.encode(payload, self.secret_key, algorithm=self.algorithm)
    
    def verify_token(self, token: str, token_type: str = "access") -> Optional[Dict[str, Any]]:
        try:
            payload = jwt.decode(
                token, 
                self.secret_key, 
                algorithms=[self.algorithm]
            )
            
            if payload.get("type") != token_type:
                return None
            
            exp = payload.get("exp")
            if exp and datetime.fromtimestamp(exp, tz=timezone.utc) < datetime.now(timezone.utc):
                return None
            
            return payload
            
        except jwt.InvalidTokenError:
            return None
    
    def get_user_id_from_token(self, token: str) -> Optional[int]:
        payload = self.verify_token(token, "access")
        if payload:
            sub = payload.get("sub")
            if sub:
                return int(sub)
        return None
    
    def get_email_from_token(self, token: str) -> Optional[str]:
        payload = self.verify_token(token, "access")
        if payload:
            return payload.get("email")
        return None
    
    def hash_refresh_token(self, refresh_token: str) -> str:
        return self.hash_password(refresh_token)
    
    def verify_refresh_token_hash(self, plain_token: str, hashed_token: str) -> bool:
        return self.verify_password(plain_token, hashed_token)

auth_manager = AuthManager()