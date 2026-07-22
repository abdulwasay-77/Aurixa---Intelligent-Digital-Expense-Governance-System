"""
AURIXA Backend - User Pydantic Models
Request and response schemas for User and Authentication
"""

from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional
from datetime import datetime


# ========================================================================
# Authentication Request/Response Models
# ========================================================================

class RegisterRequest(BaseModel):
    """Request model for user registration"""
    email: EmailStr
    password: str = Field(..., min_length=8, description="Password must be at least 8 characters")
    full_name: str = Field(..., min_length=1, max_length=150)
    phone: Optional[str] = None
    monthly_income: float = Field(..., gt=0, description="Monthly income must be greater than 0")
    saving_target_pct: float = Field(default=20, ge=0, le=100)
    risk_tolerance: str = Field(default="MEDIUM", pattern="^(LOW|MEDIUM|HIGH)$")
    lifestyle_category: Optional[str] = None
    base_currency_code: str = Field(default="USD", pattern="^(PKR|USD|EUR|GBP)$")
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        return v
    
    @validator('phone')
    def validate_phone(cls, v):
        if v and not v.isdigit():
            raise ValueError('Phone must contain only digits')
        if v and len(v) < 10:
            raise ValueError('Phone must be at least 10 digits')
        return v


class LoginRequest(BaseModel):
    """Request model for user login"""
    email: EmailStr
    password: str


class RefreshTokenRequest(BaseModel):
    """Request model for refreshing access token"""
    refresh_token: str


class TokenResponse(BaseModel):
    """Response model for authentication tokens"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in_minutes: int = 15


# ========================================================================
# User Response Models
# ========================================================================

class UserResponse(BaseModel):
    """Response model for user data (safe - no password)"""
    user_id: int
    email: str
    full_name: str
    phone: Optional[str]
    status: str
    created_at: datetime
    last_login: Optional[datetime]


class UserProfileResponse(BaseModel):
    """Response model for user profile with financial settings"""
    profile_id: int
    user_id: int
    monthly_income: float
    saving_target_pct: float
    risk_tolerance: str
    lifestyle_category: Optional[str]
    base_currency_code: str
    base_currency_symbol: str
    updated_at: datetime


class UserPreferencesResponse(BaseModel):
    """Response model for user preferences"""
    pref_id: int
    user_id: int
    notif_budget_alert: bool
    notif_billing_reminder: bool
    notif_anomaly: bool
    theme: str
    dashboard_layout: str
    biometric_enabled: bool


# ========================================================================
# Update Request Models
# ========================================================================

class UpdateProfileRequest(BaseModel):
    """Request model for updating user profile"""
    monthly_income: Optional[float] = Field(None, gt=0)
    saving_target_pct: Optional[float] = Field(None, ge=0, le=100)
    risk_tolerance: Optional[str] = Field(None, pattern="^(LOW|MEDIUM|HIGH)$")
    lifestyle_category: Optional[str] = None
    base_currency_code: Optional[str] = Field(None, pattern="^(PKR|USD|EUR|GBP)$")


class UpdatePreferencesRequest(BaseModel):
    """Request model for updating user preferences"""
    notif_budget_alert: Optional[bool] = None
    notif_billing_reminder: Optional[bool] = None
    notif_anomaly: Optional[bool] = None
    theme: Optional[str] = Field(None, pattern="^(DARK|LIGHT)$")
    dashboard_layout: Optional[str] = None
    biometric_enabled: Optional[bool] = None


class ChangePasswordRequest(BaseModel):
    """Request model for changing password"""
    current_password: str
    new_password: str = Field(..., min_length=8)
    
    @validator('new_password')
    def validate_new_password(cls, v):
        if len(v) < 8:
            raise ValueError('New password must be at least 8 characters')
        return v


# ========================================================================
# Response Messages
# ========================================================================

class MessageResponse(BaseModel):
    """Generic message response"""
    message: str
    success: bool = True


class ErrorResponse(BaseModel):
    """Error response model"""
    detail: str
    status_code: int