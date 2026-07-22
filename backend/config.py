import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    @property
    def ORACLE_USER(self):
        return os.getenv('ORACLE_USER', 'C##AURIXA')
    
    @property
    def ORACLE_PASSWORD(self):
        return os.getenv('ORACLE_PASSWORD', '')
    
    @property
    def ORACLE_DSN(self):
        return os.getenv('ORACLE_DSN', 'localhost:1521/orcl')
    
    @property
    def ORACLE_CONNECTION_STRING(self):
        return f"{self.ORACLE_USER}/{self.ORACLE_PASSWORD}@{self.ORACLE_DSN}"
    
    @property
    def JWT_SECRET(self):
        return os.getenv('JWT_SECRET', '')
    
    @property
    def JWT_ALGORITHM(self):
        return os.getenv('JWT_ALGORITHM', 'HS256')
    
    @property
    def JWT_ACCESS_EXPIRE_MINUTES(self):
        return int(os.getenv('JWT_ACCESS_EXPIRE_MINUTES', '15'))
    
    @property
    def JWT_REFRESH_EXPIRE_DAYS(self):
        return int(os.getenv('JWT_REFRESH_EXPIRE_DAYS', '7'))
    
    @property
    def ANOMALY_CONTAMINATION(self):
        return float(os.getenv('ANOMALY_CONTAMINATION', '0.05'))
    
    @property
    def ML_RANDOM_STATE(self):
        return int(os.getenv('ML_RANDOM_STATE', '42'))
    
    @property
    def API_HOST(self):
        return os.getenv('API_HOST', '127.0.0.1')
    
    @property
    def API_PORT(self):
        return int(os.getenv('API_PORT', '8000'))
    
    @property
    def API_RELOAD(self):
        return os.getenv('API_RELOAD', 'true').lower() == 'true'
    
    def is_valid(self):
        if not self.ORACLE_USER:
            return False, "ORACLE_USER is not set"
        if not self.ORACLE_PASSWORD:
            return False, "ORACLE_PASSWORD is not set"
        if not self.ORACLE_DSN:
            return False, "ORACLE_DSN is not set"
        if not self.JWT_SECRET:
            return False, "JWT_SECRET is not set"
        if len(self.JWT_SECRET) < 32:
            return False, "JWT_SECRET must be at least 32 characters"
        return True, None

config = Config()