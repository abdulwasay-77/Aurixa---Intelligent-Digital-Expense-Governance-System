from fastapi import APIRouter, HTTPException, Depends, Header
from fastapi import status
from typing import Optional
from datetime import datetime

from models.user import (
    UserResponse, UserProfileResponse, UserPreferencesResponse,
    UpdateProfileRequest, UpdatePreferencesRequest, ChangePasswordRequest,
    MessageResponse
)
from database import db
from auth import auth_manager

router = APIRouter(prefix="/api/users", tags=["Users"])


# ========================================================================
# Helper Functions
# ========================================================================

async def get_current_user_id(authorization: str = Header(None)):
    """
    Extract user_id from JWT token in Authorization header.
    This is a proper FastAPI dependency.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header"
        )
    
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Use 'Bearer <token>'"
        )
    
    token = parts[1]
    user_id = auth_manager.get_user_id_from_token(token)
    
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )
    
    return user_id


def get_currency_id(currency_code: str) -> int:
    """Get currency_id from currency code"""
    result = db.execute_query(
        "SELECT currency_id FROM CURRENCIES WHERE code = :code",
        {"code": currency_code}
    )
    if not result:
        raise HTTPException(status_code=400, detail=f"Invalid currency code: {currency_code}")
    return result[0][0]


def get_currency_code(currency_id: int) -> tuple:
    """Get currency code and symbol from currency_id"""
    result = db.execute_query(
        "SELECT code, symbol FROM CURRENCIES WHERE currency_id = :currency_id",
        {"currency_id": currency_id}
    )
    if not result:
        return "USD", "$"
    return result[0][0], result[0][1]


def get_user_by_id(user_id: int):
    """Get user by ID"""
    result = db.execute_query(
        "SELECT user_id, email, full_name, phone, status, created_at, last_login "
        "FROM USERS WHERE user_id = :user_id",
        {"user_id": user_id}
    )
    return result[0] if result else None


def get_user_profile(user_id: int):
    """Get user profile with financial settings"""
    result = db.execute_query(
        """SELECT p.profile_id, p.user_id, p.monthly_income, p.saving_target_pct, 
                  p.risk_tolerance, p.lifestyle_category, p.base_currency_id, 
                  p.updated_at, c.code, c.symbol
           FROM USER_PROFILES p
           JOIN CURRENCIES c ON p.base_currency_id = c.currency_id
           WHERE p.user_id = :user_id""",
        {"user_id": user_id}
    )
    return result[0] if result else None


def get_user_preferences(user_id: int):
    """Get user preferences"""
    result = db.execute_query(
        """SELECT pref_id, user_id, notif_budget_alert, notif_billing_reminder, 
                  notif_anomaly, theme, dashboard_layout, biometric_enabled, biometric_enrolled_at
           FROM USER_PREFERENCES 
           WHERE user_id = :user_id""",
        {"user_id": user_id}
    )
    return result[0] if result else None


# ========================================================================
# API Endpoints
# ========================================================================

@router.get("/me", response_model=UserResponse)
async def get_current_user(user_id: int = Depends(get_current_user_id)):
    """
    Get current user's basic information.
    """
    user = get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    (user_id, email, full_name, phone, status, created_at, last_login) = user
    
    return UserResponse(
        user_id=user_id,
        email=email,
        full_name=full_name,
        phone=phone,
        status=status,
        created_at=created_at,
        last_login=last_login
    )


@router.get("/profile", response_model=UserProfileResponse)
async def get_profile(user_id: int = Depends(get_current_user_id)):
    """
    Get current user's profile with financial settings.
    """
    # Check if user exists
    user = get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get profile
    profile = get_user_profile(user_id)
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found"
        )
    
    (profile_id, user_id, monthly_income, saving_target_pct, 
     risk_tolerance, lifestyle_category, base_currency_id, 
     updated_at, currency_code, currency_symbol) = profile
    
    return UserProfileResponse(
        profile_id=profile_id,
        user_id=user_id,
        monthly_income=float(monthly_income) if monthly_income else 0,
        saving_target_pct=float(saving_target_pct) if saving_target_pct else 20,
        risk_tolerance=risk_tolerance or "MEDIUM",
        lifestyle_category=lifestyle_category,
        base_currency_code=currency_code,
        base_currency_symbol=currency_symbol,
        updated_at=updated_at
    )


@router.put("/profile", response_model=MessageResponse)
async def update_profile(request: UpdateProfileRequest, user_id: int = Depends(get_current_user_id)):
    """
    Update current user's profile settings.
    """
    # Build dynamic update query
    updates = []
    params = {"user_id": user_id}
    
    if request.monthly_income is not None:
        updates.append("monthly_income = :monthly_income")
        params["monthly_income"] = request.monthly_income
    
    if request.saving_target_pct is not None:
        updates.append("saving_target_pct = :saving_target_pct")
        params["saving_target_pct"] = request.saving_target_pct
    
    if request.risk_tolerance is not None:
        updates.append("risk_tolerance = :risk_tolerance")
        params["risk_tolerance"] = request.risk_tolerance
    
    if request.lifestyle_category is not None:
        updates.append("lifestyle_category = :lifestyle_category")
        params["lifestyle_category"] = request.lifestyle_category
    
    if request.base_currency_code is not None:
        currency_id = get_currency_id(request.base_currency_code)
        updates.append("base_currency_id = :currency_id")
        params["currency_id"] = currency_id
    
    if updates:
        updates.append("updated_at = SYSDATE")
        query = f"UPDATE USER_PROFILES SET {', '.join(updates)} WHERE user_id = :user_id"
        
        try:
            db.execute_update(query, params)
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to update profile: {str(e)}"
            )
    
    return MessageResponse(message="Profile updated successfully")


@router.get("/preferences", response_model=UserPreferencesResponse)
async def get_preferences(user_id: int = Depends(get_current_user_id)):
    """
    Get current user's preferences.
    """
    preferences = get_user_preferences(user_id)
    if not preferences:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User preferences not found"
        )
    
    (pref_id, user_id, notif_budget_alert, notif_billing_reminder, 
     notif_anomaly, theme, dashboard_layout, biometric_enabled, biometric_enrolled_at) = preferences
    
    return UserPreferencesResponse(
        pref_id=pref_id,
        user_id=user_id,
        notif_budget_alert=notif_budget_alert == 'Y',
        notif_billing_reminder=notif_billing_reminder == 'Y',
        notif_anomaly=notif_anomaly == 'Y',
        theme=theme or "DARK",
        dashboard_layout=dashboard_layout or "DEFAULT",
        biometric_enabled=biometric_enabled == 'Y'
    )


@router.put("/preferences", response_model=MessageResponse)
async def update_preferences(request: UpdatePreferencesRequest, user_id: int = Depends(get_current_user_id)):
    """
    Update current user's preferences.
    """
    # Build dynamic update query
    updates = []
    params = {"user_id": user_id}
    
    if request.notif_budget_alert is not None:
        updates.append("notif_budget_alert = :notif_budget_alert")
        params["notif_budget_alert"] = 'Y' if request.notif_budget_alert else 'N'
    
    if request.notif_billing_reminder is not None:
        updates.append("notif_billing_reminder = :notif_billing_reminder")
        params["notif_billing_reminder"] = 'Y' if request.notif_billing_reminder else 'N'
    
    if request.notif_anomaly is not None:
        updates.append("notif_anomaly = :notif_anomaly")
        params["notif_anomaly"] = 'Y' if request.notif_anomaly else 'N'
    
    if request.theme is not None:
        updates.append("theme = :theme")
        params["theme"] = request.theme
    
    if request.dashboard_layout is not None:
        updates.append("dashboard_layout = :dashboard_layout")
        params["dashboard_layout"] = request.dashboard_layout
    
    if request.biometric_enabled is not None:
        updates.append("biometric_enabled = :biometric_enabled")
        params["biometric_enabled"] = 'Y' if request.biometric_enabled else 'N'
        if request.biometric_enabled:
            updates.append("biometric_enrolled_at = SYSDATE")
        else:
            updates.append("biometric_enrolled_at = NULL")
    
    if updates:
        query = f"UPDATE USER_PREFERENCES SET {', '.join(updates)} WHERE user_id = :user_id"
        
        try:
            db.execute_update(query, params)
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to update preferences: {str(e)}"
            )
    
    return MessageResponse(message="Preferences updated successfully")


@router.post("/change-password", response_model=MessageResponse)
async def change_password(request: ChangePasswordRequest, user_id: int = Depends(get_current_user_id)):
    """
    Change user's password.
    Requires current password verification.
    """
    # Get current password hash
    result = db.execute_query(
        "SELECT password_hash FROM USERS WHERE user_id = :user_id",
        {"user_id": user_id}
    )
    
    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    current_hash = result[0][0]
    
    # Verify current password
    if not auth_manager.verify_password(request.current_password, current_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current password is incorrect"
        )
    
    # Hash new password
    new_hash = auth_manager.hash_password(request.new_password)
    
    # Update password
    try:
        db.execute_update(
            "UPDATE USERS SET password_hash = :new_hash WHERE user_id = :user_id",
            {"new_hash": new_hash, "user_id": user_id}
        )
        
        # Update last_password_change in USER_SECURITY
        db.execute_update(
            "UPDATE USER_SECURITY SET last_password_change = SYSDATE WHERE user_id = :user_id",
            {"user_id": user_id}
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to change password: {str(e)}"
        )
    
    return MessageResponse(message="Password changed successfully")