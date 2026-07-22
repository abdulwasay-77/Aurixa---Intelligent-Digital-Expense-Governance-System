"""
AURIXA Backend - Recommendation Pydantic Models
Request and response schemas for AI recommendations
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ========================================================================
# Recommendation Models
# ========================================================================

class RecommendationResponse(BaseModel):
    """Response model for a single AI recommendation"""
    rec_id: int
    user_id: int
    rec_type: str  # CANCEL, DOWNGRADE, YEARLY_PLAN, CONSOLIDATE, ALTERNATIVE
    sub_id: Optional[int] = None
    sub_name: Optional[str] = None
    vendor_name: Optional[str] = None
    category_name: Optional[str] = None
    title: str
    reasoning: str
    potential_saving: Optional[float] = None
    saving_currency_code: Optional[str] = None
    saving_currency_symbol: Optional[str] = None
    confidence_score: Optional[float] = Field(None, ge=0, le=100)
    source: str  # PROCEDURE, ML_MODEL, HYBRID
    is_actioned: bool
    generated_at: datetime


class RecommendationListResponse(BaseModel):
    """Response model for paginated recommendation list"""
    recommendations: List[RecommendationResponse]
    total_count: int
    actioned_count: int
    total_potential_savings: float
    page: int
    page_size: int


class RecommendationSummaryResponse(BaseModel):
    """Summary of recommendations for dashboard"""
    total_recommendations: int
    pending_recommendations: int
    actioned_recommendations: int
    total_potential_savings: float
    by_type: dict
    top_saving_recommendation: Optional[RecommendationResponse] = None


# ========================================================================
# Action Models
# ========================================================================

class ActionRecommendationRequest(BaseModel):
    """Request model for actioning a recommendation"""
    action_taken: str  # APPLIED, DISMISSED, SCHEDULED
    notes: Optional[str] = None


class ActionRecommendationResponse(BaseModel):
    """Response model for actioning a recommendation"""
    success: bool
    message: str
    recommendation_id: int
    action_taken: str


# ========================================================================
# Savings Analysis Models
# ========================================================================

class SavingsImpactResponse(BaseModel):
    """Response model for savings impact analysis"""
    current_monthly_spend: float
    projected_monthly_spend: float
    monthly_savings: float
    yearly_savings: float
    recommendations_applied: int
    recommendations_pending: int


class RecommendationStatsResponse(BaseModel):
    """Statistics about recommendations"""
    total_generated: int
    total_actioned: int
    acceptance_rate: float
    total_savings_implemented: float
    by_type_stats: dict