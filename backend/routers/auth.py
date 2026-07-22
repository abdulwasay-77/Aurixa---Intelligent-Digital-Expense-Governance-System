"""
AURIXA Backend - Authentication Routes
Handles user registration, login, and token refresh
"""

from fastapi import APIRouter, HTTPException, Depends
from fastapi import status
from typing import Optional
from datetime import datetime, timezone, timedelta
import secrets

from models.user import (
    RegisterRequest, LoginRequest, RefreshTokenRequest,
    TokenResponse, MessageResponse, UserResponse
)
from database import db
from auth import auth_manager
from config import config

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


# ========================================================================
# Helper Functions
# ========================================================================

def get_currency_id(currency_code: str) -> int:
    """Get currency_id from currency code"""
    result = db.execute_query(
        "SELECT currency_id FROM CURRENCIES WHERE code = :code",
        {"code": currency_code}
    )
    if not result:
        raise HTTPException(status_code=400, detail=f"Invalid currency code: {currency_code}")
    return result[0][0]


def get_category_id(category_name: str) -> Optional[int]:
    """Get category_id from category name (for default categories)"""
    result = db.execute_query(
        "SELECT category_id FROM EXPENSE_CATEGORIES WHERE name = :name AND is_system = 'Y'",
        {"name": category_name}
    )
    return result[0][0] if result else None


def email_exists(email: str) -> bool:
    """Check if email already exists in database"""
    result = db.execute_query(
        "SELECT COUNT(*) FROM USERS WHERE email = :email",
        {"email": email.lower()}
    )
    return result[0][0] > 0 if result else False


def get_user_by_email(email: str):
    """Get user by email"""
    result = db.execute_query(
        "SELECT user_id, email, password_hash, full_name, status, created_at, last_login "
        "FROM USERS WHERE email = :email",
        {"email": email.lower()}
    )
    return result[0] if result else None


def update_last_login(user_id: int) -> None:
    """Update user's last login timestamp"""
    db.execute_update(
        "UPDATE USERS SET last_login = SYSDATE WHERE user_id = :user_id",
        {"user_id": user_id}
    )


def store_refresh_token(user_id: int, refresh_token: str) -> None:
    """Store hashed refresh token in USER_SECURITY table"""
    hashed_token = auth_manager.hash_refresh_token(refresh_token)
    expires_at = datetime.now(timezone.utc) + timedelta(days=config.JWT_REFRESH_EXPIRE_DAYS)
    
    # Check if user has security record
    result = db.execute_query(
        "SELECT security_id FROM USER_SECURITY WHERE user_id = :user_id",
        {"user_id": user_id}
    )
    
    if result:
        # Update existing
        db.execute_update(
            "UPDATE USER_SECURITY SET refresh_token_hash = :hash, token_expires_at = :expires "
            "WHERE user_id = :user_id",
            {"hash": hashed_token, "expires": expires_at, "user_id": user_id}
        )
    else:
        # Insert new
        db.execute_update(
            "INSERT INTO USER_SECURITY (security_id, user_id, refresh_token_hash, token_expires_at, failed_login_count) "
            "VALUES (SEQ_USER_SECURITY.NEXTVAL, :user_id, :hash, :expires, 0)",
            {"user_id": user_id, "hash": hashed_token, "expires": expires_at}
        )


def verify_refresh_token(user_id: int, refresh_token: str) -> bool:
    """Verify refresh token against stored hash"""
    result = db.execute_query(
        "SELECT refresh_token_hash, token_expires_at FROM USER_SECURITY WHERE user_id = :user_id",
        {"user_id": user_id}
    )
    
    if not result or not result[0][0]:
        return False
    
    stored_hash = result[0][0]
    expires_at = result[0][1]
    
    # Check expiration
    if expires_at and expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        return False
    
    return auth_manager.verify_refresh_token_hash(refresh_token, stored_hash)


# ========================================================================
# API Endpoints
# ========================================================================

@router.post("/register", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def register(request: RegisterRequest):
    """
    Register a new user.
    Creates records in USERS, USER_PROFILES, USER_PREFERENCES, and DIGITAL_WALLETS.
    """
    # Check if email already exists
    if email_exists(request.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Start transaction - insert into USERS
    hashed_password = auth_manager.hash_password(request.password)
    
    user_id = None
    try:
        # Insert into USERS
        db.execute_update(
            """INSERT INTO USERS 
               (user_id, email, password_hash, full_name, phone, status, created_at)
               VALUES (SEQ_USERS.NEXTVAL, :email, :password_hash, :full_name, :phone, 'ACTIVE', SYSDATE)""",
            {
                "email": request.email.lower(),
                "password_hash": hashed_password,
                "full_name": request.full_name,
                "phone": request.phone
            }
        )
        
        # Get the generated user_id
        result = db.execute_query(
            "SELECT user_id FROM USERS WHERE email = :email",
            {"email": request.email.lower()}
        )
        user_id = result[0][0] if result else None
        
        if not user_id:
            raise HTTPException(status_code=500, detail="Failed to create user")
        
        # Get currency_id
        currency_id = get_currency_id(request.base_currency_code)
        
        # Insert into USER_PROFILES
        db.execute_update(
            """INSERT INTO USER_PROFILES 
               (profile_id, user_id, monthly_income, saving_target_pct, 
                risk_tolerance, lifestyle_category, base_currency_id, updated_at)
               VALUES (SEQ_USER_PROFILES.NEXTVAL, :user_id, :monthly_income, :saving_target_pct,
                       :risk_tolerance, :lifestyle_category, :currency_id, SYSDATE)""",
            {
                "user_id": user_id,
                "monthly_income": request.monthly_income,
                "saving_target_pct": request.saving_target_pct,
                "risk_tolerance": request.risk_tolerance,
                "lifestyle_category": request.lifestyle_category,
                "currency_id": currency_id
            }
        )
        
        # Insert into USER_PREFERENCES (default values)
        db.execute_update(
            """INSERT INTO USER_PREFERENCES 
               (pref_id, user_id, notif_budget_alert, notif_billing_reminder, 
                notif_anomaly, theme, dashboard_layout, biometric_enabled)
               VALUES (SEQ_USER_PREFS.NEXTVAL, :user_id, 'Y', 'Y', 'Y', 'DARK', 'DEFAULT', 'N')""",
            {"user_id": user_id}
        )
        
        # ================================================================
        # Insert into DIGITAL_WALLETS (create PRIMARY wallet for user)
        # ================================================================
        db.execute_update(
            """INSERT INTO DIGITAL_WALLETS 
               (wallet_id, user_id, currency_id, balance, wallet_type, is_active, created_at)
               VALUES (SEQ_WALLETS.NEXTVAL, :user_id, :currency_id, 0, 'PRIMARY', 'Y', SYSDATE)""",
            {"user_id": user_id, "currency_id": currency_id}
        )
        
        return MessageResponse(
            message="User registered successfully",
            success=True
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Registration error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}"
        )


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    """
    Authenticate user and return JWT tokens.
    """
    # Get user by email
    user = get_user_by_email(request.email)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    user_id, email, password_hash, full_name, user_status, created_at, last_login = user
    
    # Check account status
    if user_status != 'ACTIVE':
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Account is {user_status}. Please contact support."
        )
    
    # Verify password
    if not auth_manager.verify_password(request.password, password_hash):
        # Increment failed login count
        db.execute_update(
            "UPDATE USER_SECURITY SET failed_login_count = NVL(failed_login_count, 0) + 1 WHERE user_id = :user_id",
            {"user_id": user_id}
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    # Reset failed login count on successful login
    db.execute_update(
        "UPDATE USER_SECURITY SET failed_login_count = 0 WHERE user_id = :user_id",
        {"user_id": user_id}
    )
    
    # Update last login
    update_last_login(user_id)
    
    # Create tokens
    access_token = auth_manager.create_access_token(user_id, email)
    refresh_token = auth_manager.create_refresh_token(user_id, email)
    
    # Store refresh token hash in database
    store_refresh_token(user_id, refresh_token)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in_minutes=config.JWT_ACCESS_EXPIRE_MINUTES
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(request: RefreshTokenRequest):
    """
    Refresh access token using a valid refresh token.
    """
    # Verify the refresh token
    payload = auth_manager.verify_token(request.refresh_token, "refresh")
    
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )
    
    user_id = int(payload.get("sub"))
    email = payload.get("email")
    
    # Verify against stored hash
    if not verify_refresh_token(user_id, request.refresh_token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    
    # Create new tokens
    new_access_token = auth_manager.create_access_token(user_id, email)
    new_refresh_token = auth_manager.create_refresh_token(user_id, email)
    
    # Store new refresh token hash
    store_refresh_token(user_id, new_refresh_token)
    
    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        expires_in_minutes=config.JWT_ACCESS_EXPIRE_MINUTES
    )


@router.post("/logout", response_model=MessageResponse)
async def logout(request: RefreshTokenRequest):
    """
    Invalidate refresh token (logout).
    """
    payload = auth_manager.verify_token(request.refresh_token, "refresh")
    
    if payload:
        user_id = int(payload.get("sub"))
        # Clear refresh token from database
        db.execute_update(
            "UPDATE USER_SECURITY SET refresh_token_hash = NULL, token_expires_at = NULL WHERE user_id = :user_id",
            {"user_id": user_id}
        )
    
    return MessageResponse(message="Logged out successfully")