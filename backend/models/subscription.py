"""
AURIXA Backend - Subscription Pydantic Models
Request and response schemas for Subscription management
"""

from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import date, datetime


# ========================================================================
# Request Models
# ========================================================================

class CreateSubscriptionRequest(BaseModel):
    """Request model for creating a new subscription"""
    vendor_name: Optional[str] = Field(None, max_length=100)
    category_name: str = Field(..., description="Must match existing category name")
    service_name: str = Field(..., min_length=1, max_length=150)
    billing_amount: float = Field(..., gt=0)
    billing_cycle: str = Field(..., pattern="^(MONTHLY|YEARLY|WEEKLY|QUARTERLY)$")
    next_billing_date: date
    start_date: date
    currency_code: str = Field(default="USD", pattern="^(PKR|USD|EUR|GBP)$")
    usage_score: int = Field(default=5, ge=1, le=10)
    notes: Optional[str] = Field(None, max_length=500)

    # ========================================================================
    # *** FIX 7 ***
    # CreateSubscriptionRequestValidator.validate_dates() used to exist below
    # this class but was never actually called anywhere in the codebase — it
    # was dead code. This is why Claude Premium could be created with
    # next_billing_date = 2026-06-10, eleven days in the past relative to
    # when the subscription was created.
    #
    # Pydantic @validator decorators run automatically on every request, so
    # this is the only way these checks actually take effect.
    # ========================================================================

    @validator('start_date')
    def start_date_not_in_future(cls, v):
        if v > date.today():
            raise ValueError("Start date cannot be in the future")
        return v

    @validator('next_billing_date')
    def next_billing_date_must_be_valid(cls, v, values):
        if v < date.today():
            raise ValueError("Next billing date must be today or in the future")
        if 'start_date' in values and values['start_date'] is not None and v < values['start_date']:
            raise ValueError("Next billing date cannot be before start date")
        return v


class UpdateSubscriptionRequest(BaseModel):
    """Request model for updating an existing subscription"""
    vendor_name: Optional[str] = Field(None, max_length=100)
    category_name: Optional[str] = None
    service_name: Optional[str] = Field(None, min_length=1, max_length=150)
    billing_amount: Optional[float] = Field(None, gt=0)
    billing_cycle: Optional[str] = Field(None, pattern="^(MONTHLY|YEARLY|WEEKLY|QUARTERLY)$")
    next_billing_date: Optional[date] = None
    usage_score: Optional[int] = Field(None, ge=1, le=10)
    status: Optional[str] = Field(None, pattern="^(ACTIVE|PAUSED|CANCELLED)$")
    notes: Optional[str] = Field(None, max_length=500)

    # *** FIX 7 *** Same past-date problem exists on update — if next_billing_date
    # is being changed, it shouldn't be allowed to land in the past either.
    # (start_date isn't editable on update, so only this one check applies here.)
    @validator('next_billing_date')
    def next_billing_date_must_be_future_if_provided(cls, v):
        if v is not None and v < date.today():
            raise ValueError("Next billing date must be today or in the future")
        return v


class UpdateUsageScoreRequest(BaseModel):
    """Request model for updating usage score only"""
    usage_score: int = Field(..., ge=1, le=10)


# ========================================================================
# Response Models
# ========================================================================

class VendorResponse(BaseModel):
    """Response model for subscription vendor"""
    vendor_id: int
    vendor_name: str
    category_name: str
    website_url: Optional[str]
    country_code: Optional[str]


class CategoryResponse(BaseModel):
    """Response model for expense category"""
    category_id: int
    name: str
    icon_code: Optional[str]
    color_hex: Optional[str]


class BillingCycleResponse(BaseModel):
    """Response model for billing cycle"""
    cycle_id: int
    billing_date: date
    amount_charged: float
    status: str
    payment_method: Optional[str]
    created_at: datetime


class SubscriptionResponse(BaseModel):
    """Response model for subscription"""
    sub_id: int
    user_id: int
    vendor_id: Optional[int]
    vendor_name: Optional[str]
    category_id: int
    category_name: str
    category_icon: Optional[str]
    category_color: Optional[str]
    currency_code: str
    currency_symbol: str
    service_name: str
    billing_amount: float
    billing_cycle: str
    next_billing_date: date
    start_date: date
    usage_score: int
    status: str
    notes: Optional[str]
    created_at: datetime
    total_spent: Optional[float] = None
    upcoming_billing_count: Optional[int] = None


class SubscriptionListResponse(BaseModel):
    """Response model for subscription list"""
    subscriptions: list[SubscriptionResponse]
    total_count: int
    active_count: int
    total_monthly_spend: float


class IdleSubscriptionResponse(BaseModel):
    """Response model for idle subscription detection"""
    sub_id: int
    service_name: str
    billing_amount: float
    usage_score: int
    days_since_use: Optional[int]
    recommendation: str

# ========================================================================
# *** FIX 7 ***
# The old CreateSubscriptionRequestValidator class that used to live here
# has been removed — its validate_dates() logic is now implemented as real
# Pydantic @validator methods directly on CreateSubscriptionRequest above,
# where it's guaranteed to actually run on every request instead of sitting
# unused.
# ========================================================================