"""
AURIXA Backend - Recommendations Routes
Handles AI-generated subscription recommendations
"""

from fastapi import APIRouter, HTTPException, Depends, Header, Query
from fastapi import status as http_status
from typing import List, Optional
from datetime import datetime, date
from dateutil.relativedelta import relativedelta

from models.recommendation import (
    RecommendationResponse, RecommendationListResponse, RecommendationSummaryResponse,
    ActionRecommendationRequest, ActionRecommendationResponse,
    SavingsImpactResponse, RecommendationStatsResponse
)
from models.user import MessageResponse
from database import db
from auth import auth_manager

router = APIRouter(prefix="/api/recommendations", tags=["Recommendations"])


# ========================================================================
# Helper Functions
# ========================================================================

async def get_current_user_id(authorization: str = Header(None)):
    """Extract user_id from JWT token"""
    if not authorization:
        raise HTTPException(
            status_code=http_status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header"
        )
    
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=http_status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Use 'Bearer <token>'"
        )
    
    token = parts[1]
    user_id = auth_manager.get_user_id_from_token(token)
    
    if not user_id:
        raise HTTPException(
            status_code=http_status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token"
        )
    
    return user_id


def get_subscription_details(sub_id: Optional[int]) -> tuple:
    """Get subscription name and vendor for a recommendation"""
    if not sub_id:
        return None, None, None
    result = db.execute_query(
        """SELECT s.service_name, v.vendor_name, ec.name 
           FROM SUBSCRIPTIONS s
           LEFT JOIN SUBSCRIPTION_VENDORS v ON s.vendor_id = v.vendor_id
           JOIN EXPENSE_CATEGORIES ec ON s.category_id = ec.category_id
           WHERE s.sub_id = :sub_id""",
        {"sub_id": sub_id}
    )
    if result:
        return result[0][0], result[0][1], result[0][2]
    return None, None, None


def get_currency_info(currency_id: Optional[int]) -> tuple:
    """Get currency code and symbol"""
    if not currency_id:
        return "USD", "$"
    result = db.execute_query(
        "SELECT code, symbol FROM CURRENCIES WHERE currency_id = :currency_id",
        {"currency_id": currency_id}
    )
    if result:
        return result[0][0], result[0][1]
    return "USD", "$"


def _apply_recommendation_to_subscription(rec_type: str, sub_id: int, user_id: int) -> Optional[str]:
    """
    Execute the real subscription change that a recommendation implies.

    Returns None on success, or an error string if something went wrong.
    Each rec_type maps to a concrete UPDATE on SUBSCRIPTIONS:

        CANCEL       → status = 'CANCELLED'
        YEARLY_PLAN  → billing_cycle = 'YEARLY',
                       billing_amount = current_amount * 12 * 0.8  (20 % off)
                       next_billing_date = today + 1 year
        DOWNGRADE    → billing_amount = current_amount * 0.7  (30 % cheaper tier)
        CONSOLIDATE  → status = 'CANCELLED'  (user consolidates into another service)
        ALTERNATIVE  → no automatic change – mark note only
    """
    # Fetch current subscription state
    sub_result = db.execute_query(
        """SELECT billing_amount, billing_cycle, next_billing_date, status
           FROM SUBSCRIPTIONS
           WHERE sub_id = :sub_id AND user_id = :user_id""",
        {"sub_id": sub_id, "user_id": user_id}
    )
    if not sub_result:
        return "Subscription not found or does not belong to this user"

    billing_amount, billing_cycle, next_billing_date, status = sub_result[0]
    billing_amount = float(billing_amount)

    try:
        if rec_type == "CANCEL":
            db.execute_update(
                "UPDATE SUBSCRIPTIONS SET status = 'CANCELLED' WHERE sub_id = :sub_id",
                {"sub_id": sub_id}
            )

        elif rec_type == "YEARLY_PLAN":
            # Only switch if currently MONTHLY (guard against double-apply)
            if billing_cycle != "MONTHLY":
                return None  # Already on yearly or other cycle, treat as no-op
            yearly_amount = round(billing_amount * 12 * 0.8, 2)  # 20 % saving
            new_next_billing = date.today() + relativedelta(years=1)
            db.execute_update(
                """UPDATE SUBSCRIPTIONS
                   SET billing_cycle      = 'YEARLY',
                       billing_amount     = :yearly_amount,
                       next_billing_date  = :next_billing_date
                   WHERE sub_id = :sub_id""",
                {
                    "yearly_amount":      yearly_amount,
                    "next_billing_date":  new_next_billing,
                    "sub_id":             sub_id,
                }
            )

        elif rec_type == "DOWNGRADE":
            # Reduce billing_amount by 30 % to reflect a lower-tier plan
            new_amount = round(billing_amount * 0.7, 2)
            db.execute_update(
                "UPDATE SUBSCRIPTIONS SET billing_amount = :new_amount WHERE sub_id = :sub_id",
                {"new_amount": new_amount, "sub_id": sub_id}
            )

        elif rec_type == "CONSOLIDATE":
            # Consolidation means cancelling this subscription
            db.execute_update(
                "UPDATE SUBSCRIPTIONS SET status = 'CANCELLED' WHERE sub_id = :sub_id",
                {"sub_id": sub_id}
            )

        elif rec_type == "ALTERNATIVE":
            # No automated change for ALTERNATIVE — the user will manually switch services.
            # We just note it in the subscription notes field.
            db.execute_update(
                """UPDATE SUBSCRIPTIONS
                   SET notes = NVL(notes || ' | ', '') || 'Recommendation: consider switching to an alternative service.'
                   WHERE sub_id = :sub_id""",
                {"sub_id": sub_id}
            )

        return None  # success

    except Exception as e:
        return str(e)


# ========================================================================
# Recommendation Endpoints
# ========================================================================

@router.get("", response_model=RecommendationListResponse)
async def get_recommendations(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    rec_type: Optional[str] = None,
    actioned_only: bool = Query(False),
    pending_only: bool = Query(False),
    user_id: int = Depends(get_current_user_id)
):
    """Get list of AI recommendations for the user."""
    conditions = ["user_id = :user_id"]
    params = {"user_id": user_id, "limit": limit, "offset": offset}
    
    if rec_type:
        conditions.append("rec_type = :rec_type")
        params["rec_type"] = rec_type
    
    if actioned_only:
        conditions.append("is_actioned = 'Y'")
    elif pending_only:
        conditions.append("is_actioned = 'N'")
    
    where_clause = " AND ".join(conditions)
    
    recs_result = db.execute_query(
        f"""SELECT rec_id, user_id, rec_type, sub_id, title, reasoning,
                  potential_saving, saving_currency_id, confidence_score, source, is_actioned, generated_at
           FROM AI_RECOMMENDATIONS
           WHERE {where_clause}
           ORDER BY potential_saving DESC NULLS LAST, confidence_score DESC
           OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY""",
        params
    )
    
    count_params = {k: v for k, v in params.items() if k not in ["limit", "offset"]}
    total_result = db.execute_query(
        f"SELECT COUNT(*) FROM AI_RECOMMENDATIONS WHERE {where_clause}",
        count_params
    )
    total_count = total_result[0][0] if total_result else 0
    
    actioned_result = db.execute_query(
        "SELECT COUNT(*) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id AND is_actioned = 'Y'",
        {"user_id": user_id}
    )
    actioned_count = actioned_result[0][0] if actioned_result else 0
    
    savings_result = db.execute_query(
        "SELECT NVL(SUM(potential_saving), 0) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id AND is_actioned = 'N'",
        {"user_id": user_id}
    )
    total_savings = float(savings_result[0][0]) if savings_result else 0
    
    recommendations = []
    for row in recs_result:
        (rec_id, uid, rec_type_val, sub_id, title, reasoning,
         potential_saving, saving_currency_id, confidence_score, source, is_actioned, generated_at) = row
        
        sub_name, vendor_name, category_name = get_subscription_details(sub_id)
        currency_code, currency_symbol = get_currency_info(saving_currency_id)
        
        recommendations.append(RecommendationResponse(
            rec_id=rec_id,
            user_id=uid,
            rec_type=rec_type_val,
            sub_id=sub_id,
            sub_name=sub_name,
            vendor_name=vendor_name,
            category_name=category_name,
            title=title,
            reasoning=reasoning,
            potential_saving=float(potential_saving) if potential_saving else None,
            saving_currency_code=currency_code,
            saving_currency_symbol=currency_symbol,
            confidence_score=float(confidence_score) if confidence_score else None,
            source=source,
            is_actioned=is_actioned == 'Y',
            generated_at=generated_at
        ))
    
    return RecommendationListResponse(
        recommendations=recommendations,
        total_count=total_count,
        actioned_count=actioned_count,
        total_potential_savings=round(total_savings, 2),
        page=offset // limit + 1 if limit > 0 else 1,
        page_size=limit
    )


@router.get("/summary", response_model=RecommendationSummaryResponse)
async def get_recommendation_summary(user_id: int = Depends(get_current_user_id)):
    """Get summary of recommendations for dashboard."""
    total_result = db.execute_query(
        "SELECT COUNT(*) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id",
        {"user_id": user_id}
    )
    total = total_result[0][0] if total_result else 0
    
    pending_result = db.execute_query(
        "SELECT COUNT(*) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id AND is_actioned = 'N'",
        {"user_id": user_id}
    )
    pending = pending_result[0][0] if pending_result else 0
    
    actioned_result = db.execute_query(
        "SELECT COUNT(*) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id AND is_actioned = 'Y'",
        {"user_id": user_id}
    )
    actioned = actioned_result[0][0] if actioned_result else 0
    
    savings_result = db.execute_query(
        "SELECT NVL(SUM(potential_saving), 0) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id AND is_actioned = 'N'",
        {"user_id": user_id}
    )
    total_savings = float(savings_result[0][0]) if savings_result else 0
    
    type_result = db.execute_query(
        """SELECT rec_type, COUNT(*) 
           FROM AI_RECOMMENDATIONS 
           WHERE user_id = :user_id 
           GROUP BY rec_type""",
        {"user_id": user_id}
    )
    by_type = {row[0]: row[1] for row in type_result}
    
    top_result = db.execute_query(
        """SELECT rec_id, user_id, rec_type, sub_id, title, reasoning,
                  potential_saving, saving_currency_id, confidence_score, source, is_actioned, generated_at
           FROM AI_RECOMMENDATIONS
           WHERE user_id = :user_id AND is_actioned = 'N'
           ORDER BY potential_saving DESC NULLS LAST
           FETCH FIRST 1 ROW ONLY""",
        {"user_id": user_id}
    )
    
    top_recommendation = None
    if top_result:
        row = top_result[0]
        (rec_id, uid, rec_type_val, sub_id, title, reasoning,
         potential_saving, saving_currency_id, confidence_score, source, is_actioned, generated_at) = row
        
        sub_name, vendor_name, category_name = get_subscription_details(sub_id)
        currency_code, currency_symbol = get_currency_info(saving_currency_id)
        
        top_recommendation = RecommendationResponse(
            rec_id=rec_id,
            user_id=uid,
            rec_type=rec_type_val,
            sub_id=sub_id,
            sub_name=sub_name,
            vendor_name=vendor_name,
            category_name=category_name,
            title=title,
            reasoning=reasoning,
            potential_saving=float(potential_saving) if potential_saving else None,
            saving_currency_code=currency_code,
            saving_currency_symbol=currency_symbol,
            confidence_score=float(confidence_score) if confidence_score else None,
            source=source,
            is_actioned=is_actioned == 'Y',
            generated_at=generated_at
        )
    
    return RecommendationSummaryResponse(
        total_recommendations=total,
        pending_recommendations=pending,
        actioned_recommendations=actioned,
        total_potential_savings=round(total_savings, 2),
        by_type=by_type,
        top_saving_recommendation=top_recommendation
    )


@router.get("/{rec_id}", response_model=RecommendationResponse)
async def get_recommendation(rec_id: int, user_id: int = Depends(get_current_user_id)):
    """Get a single recommendation by ID."""
    result = db.execute_query(
        """SELECT rec_id, user_id, rec_type, sub_id, title, reasoning,
                  potential_saving, saving_currency_id, confidence_score, source, is_actioned, generated_at
           FROM AI_RECOMMENDATIONS
           WHERE rec_id = :rec_id AND user_id = :user_id""",
        {"rec_id": rec_id, "user_id": user_id}
    )
    
    if not result:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Recommendation not found"
        )
    
    row = result[0]
    (rec_id, uid, rec_type_val, sub_id, title, reasoning,
     potential_saving, saving_currency_id, confidence_score, source, is_actioned, generated_at) = row
    
    sub_name, vendor_name, category_name = get_subscription_details(sub_id)
    currency_code, currency_symbol = get_currency_info(saving_currency_id)
    
    return RecommendationResponse(
        rec_id=rec_id,
        user_id=uid,
        rec_type=rec_type_val,
        sub_id=sub_id,
        sub_name=sub_name,
        vendor_name=vendor_name,
        category_name=category_name,
        title=title,
        reasoning=reasoning,
        potential_saving=float(potential_saving) if potential_saving else None,
        saving_currency_code=currency_code,
        saving_currency_symbol=currency_symbol,
        confidence_score=float(confidence_score) if confidence_score else None,
        source=source,
        is_actioned=is_actioned == 'Y',
        generated_at=generated_at
    )


@router.put("/{rec_id}/action", response_model=ActionRecommendationResponse)
async def action_recommendation(
    rec_id: int,
    request: ActionRecommendationRequest,
    user_id: int = Depends(get_current_user_id)
):
    """
    Mark a recommendation as actioned AND apply the real subscription change.

    When action_taken == 'APPLIED':
        - Executes the actual UPDATE on SUBSCRIPTIONS based on rec_type
          (CANCEL → cancelled, YEARLY_PLAN → billing_cycle+amount changed, etc.)
        - Then marks the recommendation is_actioned = 'Y'

    When action_taken == 'DISMISSED':
        - Only marks is_actioned = 'Y' — no subscription change.
    """
    # Fetch full recommendation row (need rec_type and sub_id)
    result = db.execute_query(
        """SELECT rec_id, rec_type, sub_id, is_actioned
           FROM AI_RECOMMENDATIONS
           WHERE rec_id = :rec_id AND user_id = :user_id""",
        {"rec_id": rec_id, "user_id": user_id}
    )
    
    if not result:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Recommendation not found"
        )
    
    db_rec_id, rec_type, sub_id, is_actioned = result[0]

    if is_actioned == 'Y':
        raise HTTPException(
            status_code=http_status.HTTP_400_BAD_REQUEST,
            detail="Recommendation already actioned"
        )
    
    # ── Apply the real subscription change when action is APPLIED ────────────
    if request.action_taken == "APPLIED" and sub_id is not None:
        error = _apply_recommendation_to_subscription(rec_type, sub_id, user_id)
        if error:
            raise HTTPException(
                status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to apply recommendation to subscription: {error}"
            )
    # ─────────────────────────────────────────────────────────────────────────

    # Mark recommendation as actioned
    db.execute_update(
        "UPDATE AI_RECOMMENDATIONS SET is_actioned = 'Y' WHERE rec_id = :rec_id",
        {"rec_id": rec_id}
    )
    
    action_label = request.action_taken  # "APPLIED" or "DISMISSED"
    return ActionRecommendationResponse(
        success=True,
        message=f"Recommendation {action_label.lower()} successfully",
        recommendation_id=rec_id,
        action_taken=action_label
    )


@router.post("/generate", response_model=MessageResponse)
async def generate_recommendations(user_id: int = Depends(get_current_user_id)):
    """
    Manually trigger recommendation generation using Oracle Service.
    Integrated with services/oracle_service.py
    """
    from services.oracle_service import oracle_service
    
    try:
        success = oracle_service.generate_smart_recommendations(user_id)
        
        if success:
            result = db.execute_query(
                "SELECT COUNT(*) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id AND generated_at >= SYSDATE - 1/24",
                {"user_id": user_id}
            )
            count = result[0][0] if result else 0
            
            return MessageResponse(
                message=f"Recommendations generated successfully. {count} new recommendations created.",
                success=True
            )
        else:
            return MessageResponse(
                message="Failed to generate recommendations. Check Oracle procedure.",
                success=False
            )
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate recommendations: {str(e)}"
        )


@router.get("/savings/impact", response_model=SavingsImpactResponse)
async def get_savings_impact(user_id: int = Depends(get_current_user_id)):
    """Calculate potential savings impact of recommendations."""
    spend_result = db.execute_query(
        "SELECT NVL(SUM(billing_amount), 0) FROM SUBSCRIPTIONS WHERE user_id = :user_id AND status = 'ACTIVE'",
        {"user_id": user_id}
    )
    current_spend = float(spend_result[0][0]) if spend_result else 0
    
    savings_result = db.execute_query(
        "SELECT NVL(SUM(potential_saving), 0) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id AND is_actioned = 'N'",
        {"user_id": user_id}
    )
    pending_savings = float(savings_result[0][0]) if savings_result else 0
    
    applied_result = db.execute_query(
        "SELECT NVL(SUM(potential_saving), 0) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id AND is_actioned = 'Y'",
        {"user_id": user_id}
    )
    applied_savings = float(applied_result[0][0]) if applied_result else 0
    
    count_result = db.execute_query(
        "SELECT COUNT(*), SUM(CASE WHEN is_actioned = 'Y' THEN 1 ELSE 0 END) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id",
        {"user_id": user_id}
    )
    total_recs = count_result[0][0] if count_result else 0
    applied_recs = count_result[0][1] if count_result and count_result[0][1] else 0
    
    return SavingsImpactResponse(
        current_monthly_spend=round(current_spend, 2),
        projected_monthly_spend=round(current_spend - pending_savings, 2),
        monthly_savings=round(pending_savings, 2),
        yearly_savings=round(pending_savings * 12, 2),
        recommendations_applied=applied_recs,
        recommendations_pending=total_recs - applied_recs
    )


@router.get("/stats/overview", response_model=RecommendationStatsResponse)
async def get_recommendation_stats(user_id: int = Depends(get_current_user_id)):
    """Get statistics about recommendations."""
    result = db.execute_query(
        """SELECT COUNT(*) as total,
                  SUM(CASE WHEN is_actioned = 'Y' THEN 1 ELSE 0 END) as actioned,
                  NVL(SUM(CASE WHEN is_actioned = 'Y' THEN potential_saving ELSE 0 END), 0) as savings
           FROM AI_RECOMMENDATIONS
           WHERE user_id = :user_id""",
        {"user_id": user_id}
    )
    
    total = result[0][0] if result else 0
    actioned = result[0][1] if result and result[0][1] else 0
    savings = float(result[0][2]) if result else 0
    
    acceptance_rate = (actioned / total * 100) if total > 0 else 0
    
    type_result = db.execute_query(
        """SELECT rec_type, COUNT(*), SUM(CASE WHEN is_actioned = 'Y' THEN 1 ELSE 0 END)
           FROM AI_RECOMMENDATIONS
           WHERE user_id = :user_id
           GROUP BY rec_type""",
        {"user_id": user_id}
    )
    by_type_stats = {}
    for row in type_result:
        rec_type, count, actioned_count = row
        by_type_stats[rec_type] = {
            "total": count,
            "actioned": actioned_count or 0,
            "rate": round((actioned_count or 0) / count * 100, 2) if count > 0 else 0
        }
    
    return RecommendationStatsResponse(
        total_generated=total,
        total_actioned=actioned,
        acceptance_rate=round(acceptance_rate, 2),
        total_savings_implemented=round(savings, 2),
        by_type_stats=by_type_stats
    )