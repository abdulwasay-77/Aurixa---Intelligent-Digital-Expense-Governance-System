"""
AURIXA Backend - Analytics Pydantic Models
Request and response schemas for Analytics endpoints
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, datetime


# ========================================================================
# Financial Score Models
# ========================================================================

class FinancialScoreResponse(BaseModel):
    """Response model for financial health score"""
    score_id: int
    user_id: int
    score_date: date
    financial_health_score: float = Field(..., ge=0, le=100)
    savings_rate_score: Optional[float] = Field(None, ge=0, le=100)
    budget_discipline_score: Optional[float] = Field(None, ge=0, le=100)
    sub_dependency_ratio: Optional[float] = Field(None, ge=0, le=100)
    risk_factor_score: Optional[float] = Field(None, ge=0, le=100)
    score_label: str


class ScoreTrendPoint(BaseModel):
    """Individual trend point for score history"""
    score_month: date
    avg_score: float
    peak_score: float
    low_score: float


class ScoreTrendResponse(BaseModel):
    """Response model for score trend over time"""
    trend: List[ScoreTrendPoint]
    current_score: float
    current_label: str
    improvement: Optional[float] = None  # Percentage change from previous month


# ========================================================================
# Budget Forecast Models
# ========================================================================

class BudgetForecastResponse(BaseModel):
    """Response model for budget forecast"""
    forecast_id: int
    forecast_month: date
    projected_total: float
    budget_limit: float
    variance_pct: Optional[float] = None
    days_to_breach: Optional[int] = None
    velocity_per_day: Optional[float] = None
    is_breached: bool = False
    generated_at: datetime


class CurrentMonthForecast(BaseModel):
    """Current month forecast with insights"""
    month: date
    spent_so_far: float
    budget_limit: float
    projected_total: float
    remaining_budget: float
    days_remaining: int
    daily_allowance: float
    current_velocity: float
    variance_pct: float
    days_to_breach: Optional[int] = None
    status: str  # "ON_TRACK", "AT_RISK", "BREACHED", "UNDER_BUDGET"
    message: str


# ========================================================================
# Category Analytics Models
# ========================================================================

class CategorySpendResponse(BaseModel):
    """Response model for category spending"""
    category_name: str
    category_id: int
    icon_code: Optional[str]
    color_hex: Optional[str]
    total_amount: float
    payment_count: int
    pct_of_total: float
    month: date


class MonthlyCategorySummary(BaseModel):
    """Monthly summary of category spending"""
    month: date
    total_spend: float
    top_category: str
    top_category_amount: float
    categories: List[CategorySpendResponse]


class SpendingPatternResponse(BaseModel):
    """Response model for spending patterns"""
    pattern_id: int
    category_name: str
    pattern_month: date
    total_spent: float
    txn_count: int
    avg_txn_amount: Optional[float] = None
    mom_change_pct: Optional[float] = None


# ========================================================================
# Day of Week Spending Model (NEW)
# ========================================================================

class DayOfWeekSpend(BaseModel):
    """Response model for day-of-week spending"""
    day_of_week: str  # MON, TUE, WED, THU, FRI, SAT, SUN
    total_amount: float
    transaction_count: int


# ========================================================================
# Transaction Analytics Models
# ========================================================================

class TransactionSummaryResponse(BaseModel):
    """Response model for transaction summary"""
    total_transactions: int
    total_debits: float
    total_credits: float
    average_transaction: float
    largest_transaction: float
    anomaly_count: int
    recurring_count: int


class MonthlySpendSummary(BaseModel):
    """Monthly spend summary for dashboard"""
    month: date
    total_spend: float
    subscription_spend: float
    other_spend: float
    active_subscriptions: int
    new_subscriptions: int
    cancelled_subscriptions: int


# ========================================================================
# Manual Trigger Models
# ========================================================================

class ManualTriggerResponse(BaseModel):
    """Response model for manual trigger of analytics jobs"""
    message: str
    success: bool
    details: Optional[str] = None