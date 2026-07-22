"""
AURIXA Backend - Analytics Routes
Handles financial scores, forecasts, and spending analytics
"""

from fastapi import APIRouter, HTTPException, Depends, Header, Query
from fastapi import status as http_status
from typing import List, Optional
from datetime import date, datetime, timedelta

from models.analytics import (
    FinancialScoreResponse, ScoreTrendResponse, ScoreTrendPoint,
    BudgetForecastResponse, CurrentMonthForecast,
    CategorySpendResponse, MonthlyCategorySummary, SpendingPatternResponse,
    DayOfWeekSpend, ManualTriggerResponse
)
from models.user import MessageResponse
from database import db
from auth import auth_manager

router = APIRouter(prefix="/api/analytics", tags=["Analytics"])


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


def get_current_month_spent(user_id: int) -> float:
    """Get total spent in current month from billing cycles"""
    result = db.execute_query(
        """SELECT NVL(SUM(bc.amount_charged), 0)
           FROM BILLING_CYCLES bc
           JOIN SUBSCRIPTIONS s ON bc.sub_id = s.sub_id
           WHERE s.user_id = :user_id
           AND bc.status = 'PAID'
           AND TRUNC(bc.billing_date, 'MM') = TRUNC(SYSDATE, 'MM')""",
        {"user_id": user_id}
    )
    return float(result[0][0]) if result else 0.0


def get_user_budget(user_id: int) -> float:
    """Get user's monthly budget (income - savings target)"""
    result = db.execute_query(
        """SELECT monthly_income * (1 - saving_target_pct/100)
           FROM USER_PROFILES
           WHERE user_id = :user_id""",
        {"user_id": user_id}
    )
    return float(result[0][0]) if result else 0.0


# ========================================================================
# Financial Score Endpoints
# ========================================================================

@router.get("/score", response_model=FinancialScoreResponse)
async def get_latest_score(user_id: int = Depends(get_current_user_id)):
    """Get the latest financial health score for the user."""
    result = db.execute_query(
        """SELECT score_id, user_id, score_date, financial_health_score,
                  savings_rate_score, budget_discipline_score,
                  sub_dependency_ratio, risk_factor_score, score_label
           FROM FINANCIAL_SCORES
           WHERE user_id = :user_id
           ORDER BY score_date DESC
           FETCH FIRST 1 ROW ONLY""",
        {"user_id": user_id}
    )
    
    # ✅ FIX: Check if result is empty
    if not result:
        return FinancialScoreResponse(
            score_id=0,
            user_id=user_id,
            score_date=date.today(),
            financial_health_score=50.0,
            savings_rate_score=None,
            budget_discipline_score=None,
            sub_dependency_ratio=None,
            risk_factor_score=None,
            score_label="NOT_CALCULATED"
        )
    
    # ✅ FIX: Get the first row BEFORE unpacking
    row = result[0]
    
    # ✅ Now unpack from the row (not from result)
    (score_id, user_id, score_date, health_score,
     savings_rate, budget_disc, sub_dep, risk_factor, label) = row
    
    return FinancialScoreResponse(
        score_id=score_id,
        user_id=user_id,
        score_date=score_date,
        financial_health_score=float(health_score),
        savings_rate_score=float(savings_rate) if savings_rate else None,
        budget_discipline_score=float(budget_disc) if budget_disc else None,
        sub_dependency_ratio=float(sub_dep) if sub_dep else None,
        risk_factor_score=float(risk_factor) if risk_factor else None,
        score_label=label or "UNKNOWN"
    )


@router.get("/score/trend", response_model=ScoreTrendResponse)
async def get_score_trend(user_id: int = Depends(get_current_user_id)):
    """Get 6-month financial health score trend."""
    result = db.execute_query(
        """SELECT score_month, avg_score, peak_score, low_score
           FROM MV_HEALTH_SCORE_TREND
           WHERE user_id = :user_id
           ORDER BY score_month ASC""",
        {"user_id": user_id}
    )
    
    trend_points = []
    for row in result:
        score_month, avg_score, peak_score, low_score = row
        trend_points.append(ScoreTrendPoint(
            score_month=score_month,
            avg_score=float(avg_score) if avg_score else 0,
            peak_score=float(peak_score) if peak_score else 0,
            low_score=float(low_score) if low_score else 0
        ))
    
    current = await get_latest_score(user_id)
    
    improvement = None
    if len(trend_points) >= 2:
        prev_avg = trend_points[-2].avg_score if len(trend_points) >= 2 else None
        curr_avg = trend_points[-1].avg_score if trend_points else None
        if prev_avg and curr_avg and prev_avg > 0:
            improvement = round(((curr_avg - prev_avg) / prev_avg) * 100, 2)
    
    return ScoreTrendResponse(
        trend=trend_points,
        current_score=current.financial_health_score,
        current_label=current.score_label,
        improvement=improvement
    )


# ========================================================================
# Budget Forecast Endpoints
# ========================================================================

@router.get("/forecast", response_model=BudgetForecastResponse)
async def get_latest_forecast(user_id: int = Depends(get_current_user_id)):
    """Get the latest budget forecast for the user."""
    result = db.execute_query(
        """SELECT forecast_id, user_id, forecast_month, projected_total,
                  budget_limit, variance_pct, days_to_breach, velocity_per_day, generated_at
           FROM BUDGET_FORECASTS
           WHERE user_id = :user_id
           ORDER BY forecast_month DESC, generated_at DESC
           FETCH FIRST 1 ROW ONLY""",
        {"user_id": user_id}
    )
    
    # ✅ FIX: Check if result is empty
    if not result:
        spent = get_current_month_spent(user_id)
        budget = get_user_budget(user_id)
        days_passed = date.today().day
        days_in_month = (date.today().replace(day=28) + timedelta(days=4)).replace(day=1).day
        velocity = spent / max(days_passed, 1)
        projected = velocity * days_in_month
        
        return BudgetForecastResponse(
            forecast_id=0,
            forecast_month=date.today().replace(day=1),
            projected_total=round(projected, 2),
            budget_limit=round(budget, 2),
            variance_pct=round(((projected - budget) / budget * 100), 2) if budget > 0 else 0,
            days_to_breach=None,
            velocity_per_day=round(velocity, 2),
            generated_at=datetime.now(),
            is_breached=spent > budget
        )
    
    # ✅ FIX: Get the first row BEFORE unpacking
    row = result[0]
    
    # ✅ Now unpack from the row
    (forecast_id, user_id, forecast_month, projected_total,
     budget_limit, variance_pct, days_to_breach, velocity_per_day, generated_at) = row
    
    spent = get_current_month_spent(user_id)
    
    return BudgetForecastResponse(
        forecast_id=forecast_id,
        forecast_month=forecast_month,
        projected_total=float(projected_total),
        budget_limit=float(budget_limit),
        variance_pct=float(variance_pct) if variance_pct else None,
        days_to_breach=days_to_breach,
        velocity_per_day=float(velocity_per_day) if velocity_per_day else None,
        generated_at=generated_at,
        is_breached=spent > float(budget_limit)
    )


@router.get("/forecast/current", response_model=CurrentMonthForecast)
async def get_current_month_forecast(user_id: int = Depends(get_current_user_id)):
    """Get detailed current month forecast with insights."""
    spent = get_current_month_spent(user_id)
    budget = get_user_budget(user_id)
    
    today = date.today()
    days_passed = today.day
    days_in_month = (today.replace(day=28) + timedelta(days=4)).replace(day=1).day
    days_remaining = days_in_month - days_passed
    
    velocity = spent / max(days_passed, 1)
    projected = velocity * days_in_month
    variance = ((projected - budget) / budget * 100) if budget > 0 else 0
    remaining_budget = max(budget - spent, 0)
    daily_allowance = remaining_budget / max(days_remaining, 1)
    
    # FIX: days_to_breach is only meaningful when the user is actually
    # projected to exceed budget. It used to be (re)computed for every
    # under-budget scenario too, producing large, meaningless numbers
    # (e.g. "553 days to breach") that the dashboard would still display
    # as a warning even when the status was comfortably UNDER_BUDGET or
    # ON_TRACK. Now it's computed once, only inside the AT_RISK branch,
    # and stays None everywhere else.
    days_to_breach = None

    if spent > budget:
        status = "BREACHED"
        message = f"Budget breached by ${abs(spent - budget):.2f}. Review subscriptions immediately."
    elif projected > budget:
        days_to_breach = int((budget - spent) / max(velocity, 0.01)) if velocity > 0 else days_remaining
        status = "AT_RISK"
        message = f"On track to exceed budget by ${projected - budget:.2f} in {days_to_breach} days."
    elif variance < -10:
        status = "UNDER_BUDGET"
        message = f"Excellent! You are ${budget - projected:.2f} under budget this month."
    else:
        status = "ON_TRACK"
        message = f"You are on track to stay within budget. Daily allowance: ${daily_allowance:.2f}"
    
    return CurrentMonthForecast(
        month=today.replace(day=1),
        spent_so_far=round(spent, 2),
        budget_limit=round(budget, 2),
        projected_total=round(projected, 2),
        remaining_budget=round(remaining_budget, 2),
        days_remaining=days_remaining,
        daily_allowance=round(daily_allowance, 2),
        current_velocity=round(velocity, 2),
        variance_pct=round(variance, 2),
        days_to_breach=days_to_breach,
        status=status,
        message=message
    )


# ========================================================================
# Category Analytics Endpoints
# ========================================================================

@router.get("/categories", response_model=List[CategorySpendResponse])
async def get_category_spending(
    month: Optional[str] = None,
    user_id: int = Depends(get_current_user_id)
):
    """Get category spending breakdown for a specific month.

    FIX: previously read only from BILLING_CYCLES (joined through
    SUBSCRIPTIONS), so any manual/non-subscription debit recorded
    directly on TRANSACTIONS with a category_id was silently excluded
    from this chart. Now reads straight from TRANSACTIONS, which has
    its own category_id and covers both subscription-linked and
    standalone debits.
    """
    if month:
        target_month = datetime.strptime(month, "%Y-%m").date()
    else:
        target_month = date.today().replace(day=1)
    
    result = db.execute_query(
        """SELECT ec.name as category_name, ec.category_id, ec.icon_code, ec.color_hex,
                  SUM(t.amount) as total_amount,
                  COUNT(t.txn_id) as payment_count
           FROM TRANSACTIONS t
           JOIN EXPENSE_CATEGORIES ec ON t.category_id = ec.category_id
           WHERE t.user_id = :user_id
           AND t.txn_type = 'DEBIT'
           AND TRUNC(t.txn_date, 'MM') = TRUNC(:target_month, 'MM')
           GROUP BY ec.name, ec.category_id, ec.icon_code, ec.color_hex
           ORDER BY total_amount DESC""",
        {"user_id": user_id, "target_month": target_month}
    )
    
    total = sum(float(row[4]) for row in result) if result else 0
    
    categories = []
    for row in result:
        cat_name, cat_id, icon, color, amount, count = row
        categories.append(CategorySpendResponse(
            category_name=cat_name,
            category_id=cat_id,
            icon_code=icon,
            color_hex=color,
            total_amount=float(amount),
            payment_count=count,
            pct_of_total=round((float(amount) / total * 100), 2) if total > 0 else 0,
            month=target_month
        ))
    
    return categories


@router.get("/categories/monthly-summary", response_model=List[MonthlyCategorySummary])
async def get_monthly_category_summary(
    months: int = 6,
    user_id: int = Depends(get_current_user_id)
):
    """Get monthly category spending summary for the last N months.

    FIX: previously read only from BILLING_CYCLES (subscriptions only).
    Now reads from TRANSACTIONS so the trend bar chart reflects all
    debit spending, not just subscription billing.
    """
    result = db.execute_query(
        """SELECT TRUNC(t.txn_date, 'MM') as month,
                  ec.name as category_name, ec.category_id, ec.icon_code, ec.color_hex,
                  SUM(t.amount) as total_amount,
                  COUNT(t.txn_id) as payment_count
           FROM TRANSACTIONS t
           JOIN EXPENSE_CATEGORIES ec ON t.category_id = ec.category_id
           WHERE t.user_id = :user_id
           AND t.txn_type = 'DEBIT'
           AND t.txn_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -:months)
           GROUP BY TRUNC(t.txn_date, 'MM'), ec.name, ec.category_id, ec.icon_code, ec.color_hex
           ORDER BY month DESC, total_amount DESC""",
        {"user_id": user_id, "months": months}
    )
    
    months_data = {}
    for row in result:
        month, cat_name, cat_id, icon, color, amount, count = row
        month_key = month.strftime("%Y-%m")
        
        if month_key not in months_data:
            months_data[month_key] = {
                "month": month,
                "categories": [],
                "total": 0,
                "top_category": None,
                "top_amount": 0
            }
        
        months_data[month_key]["categories"].append({
            "name": cat_name,
            "category_id": cat_id,
            "icon_code": icon,
            "color_hex": color,
            "amount": float(amount),
            "count": count
        })
        months_data[month_key]["total"] += float(amount)
        
        if float(amount) > months_data[month_key]["top_amount"]:
            months_data[month_key]["top_amount"] = float(amount)
            months_data[month_key]["top_category"] = cat_name
    
    summaries = []
    for month_key, data in sorted(months_data.items(), reverse=True):
        categories = []
        for cat in data["categories"]:
            categories.append(CategorySpendResponse(
                category_name=cat["name"],
                category_id=cat["category_id"],
                icon_code=cat["icon_code"],
                color_hex=cat["color_hex"],
                total_amount=cat["amount"],
                payment_count=cat["count"],
                pct_of_total=round((cat["amount"] / data["total"] * 100), 2) if data["total"] > 0 else 0,
                month=data["month"]
            ))
        
        summaries.append(MonthlyCategorySummary(
            month=data["month"],
            total_spend=round(data["total"], 2),
            top_category=data["top_category"] or "None",
            top_category_amount=round(data["top_amount"], 2),
            categories=categories
        ))
    
    return summaries


# ========================================================================
# Patterns Endpoint with Month Filter
# ========================================================================

@router.get("/patterns", response_model=List[SpendingPatternResponse])
async def get_spending_patterns(
    month: Optional[str] = None,
    user_id: int = Depends(get_current_user_id)
):
    """
    Get spending patterns with optional month filter.
    If month is provided (YYYY-MM), only returns patterns for that month.
    """
    params = {"user_id": user_id}
    query = """
        SELECT sp.pattern_id, ec.name as category_name, sp.pattern_month,
               sp.total_spent, sp.txn_count, sp.avg_txn_amount, sp.mom_change_pct
        FROM SPENDING_PATTERNS sp
        JOIN EXPENSE_CATEGORIES ec ON sp.category_id = ec.category_id
        WHERE sp.user_id = :user_id
    """
    
    if month:
        target_month = datetime.strptime(month, "%Y-%m").date()
        query += " AND TRUNC(sp.pattern_month, 'MM') = TRUNC(:target_month, 'MM')"
        params["target_month"] = target_month
    
    query += " ORDER BY sp.pattern_month DESC"
    
    result = db.execute_query(query, params)
    
    patterns = []
    for row in result:
        pattern_id, cat_name, pattern_month, total_spent, txn_count, avg_amount, mom_change = row
        patterns.append(SpendingPatternResponse(
            pattern_id=pattern_id,
            category_name=cat_name,
            pattern_month=pattern_month,
            total_spent=float(total_spent),
            txn_count=txn_count,
            avg_txn_amount=float(avg_amount) if avg_amount else 0,
            mom_change_pct=float(mom_change) if mom_change else None
        ))
    
    return patterns


# ========================================================================
# Day of Week Spending Endpoint (Uses TRANSACTIONS table)
# ========================================================================

@router.get("/day-of-week", response_model=List[DayOfWeekSpend])
async def get_day_of_week_spending(
    month: Optional[str] = None,
    user_id: int = Depends(get_current_user_id)
):
    """
    Get spending breakdown by day of week for the selected month.
    Uses TRANSACTIONS table (real transaction dates) for accurate day-of-week distribution.
    """
    params = {"user_id": user_id}
    
    # Base query using TRANSACTIONS table
    query = """
        SELECT 
            TO_CHAR(t.txn_date, 'DY') as day_of_week,
            SUM(t.amount) as total_amount,
            COUNT(*) as transaction_count
        FROM TRANSACTIONS t
        WHERE t.user_id = :user_id
        AND t.txn_type = 'DEBIT'
    """
    
    # Apply month filter if provided
    if month:
        target_month = datetime.strptime(month, "%Y-%m").date()
        query += """ 
            AND t.txn_date >= TRUNC(:target_month, 'MM')
            AND t.txn_date < ADD_MONTHS(TRUNC(:target_month, 'MM'), 1)
        """
        params["target_month"] = target_month
    else:
        # Default to current month
        query += """
            AND t.txn_date >= TRUNC(SYSDATE, 'MM')
            AND t.txn_date < ADD_MONTHS(TRUNC(SYSDATE, 'MM'), 1)
        """
    
    query += """
        GROUP BY TO_CHAR(t.txn_date, 'DY')
        ORDER BY 
            CASE TO_CHAR(t.txn_date, 'DY')
                WHEN 'MON' THEN 1
                WHEN 'TUE' THEN 2
                WHEN 'WED' THEN 3
                WHEN 'THU' THEN 4
                WHEN 'FRI' THEN 5
                WHEN 'SAT' THEN 6
                WHEN 'SUN' THEN 7
            END
    """
    
    result = db.execute_query(query, params)
    
    day_of_week_spending = []
    for row in result:
        day_of_week, total_amount, transaction_count = row
        day_of_week_spending.append(DayOfWeekSpend(
            day_of_week=day_of_week,
            total_amount=float(total_amount) if total_amount else 0,
            transaction_count=transaction_count or 0
        ))
    
    return day_of_week_spending


# ========================================================================
# Insights Endpoint (Integrated with Summary Service)
# ========================================================================

@router.get("/insights")
async def get_financial_insights(user_id: int = Depends(get_current_user_id)):
    """
    Get AI-generated financial insights using summary_service.
    Integrated with services/summary_service.py
    """
    from services.summary_service import summary_service
    
    # Get current score
    score = await get_latest_score(user_id)
    
    # Get current forecast
    forecast = await get_current_month_forecast(user_id)
    
    # Generate primary insight
    insight = summary_service.generate_financial_insight(
        {
            "financial_health_score": score.financial_health_score,
            "score_label": score.score_label
        },
        {
            "variance_pct": forecast.variance_pct,
            "days_to_breach": forecast.days_to_breach,
            "velocity_per_day": forecast.current_velocity,
            "top_category": "subscriptions"
        }
    )
    
    # Get subscription insights
    subs_result = db.execute_query(
        """SELECT service_name, billing_amount, usage_score
           FROM SUBSCRIPTIONS
           WHERE user_id = :user_id AND status = 'ACTIVE'
           ORDER BY usage_score ASC
           FETCH FIRST 3 ROWS ONLY""",
        {"user_id": user_id}
    )
    
    subscription_insights = []
    for row in subs_result:
        service_name, amount, usage = row
        subscription_insights.append(
            summary_service.generate_subscription_insight({
                "service_name": service_name,
                "billing_amount": float(amount),
                "usage_score": usage
            })
        )
    
    # Get budget insight
    budget_insight = summary_service.generate_budget_insight(
        forecast.budget_limit,
        forecast.spent_so_far,
        forecast.days_remaining
    )
    
    # Get savings insight
    savings_result = db.execute_query(
        "SELECT NVL(SUM(potential_saving), 0), COUNT(*) FROM AI_RECOMMENDATIONS WHERE user_id = :user_id AND is_actioned = 'N'",
        {"user_id": user_id}
    )
    potential_savings = float(savings_result[0][0]) if savings_result else 0
    pending_count = savings_result[0][1] if savings_result else 0
    
    savings_insight = summary_service.generate_savings_insight(potential_savings, pending_count)
    
    return {
        "primary_insight": insight,
        "subscription_insights": subscription_insights,
        "budget_insight": budget_insight,
        "savings_insight": savings_insight,
        "generated_at": datetime.now()
    }


# ========================================================================
# Manual Trigger Endpoints
# ========================================================================

@router.post("/run-health-score", response_model=ManualTriggerResponse)
async def trigger_health_score(user_id: int = Depends(get_current_user_id)):
    """Manually trigger financial health score calculation."""
    from services.oracle_service import oracle_service
    
    try:
        success = oracle_service.calculate_financial_health(user_id)
        if success:
            return ManualTriggerResponse(
                message="Financial health score calculation triggered successfully",
                success=True,
                details="Score will be available in FINANCIAL_SCORES table"
            )
        else:
            return ManualTriggerResponse(
                message="Failed to trigger health score calculation",
                success=False,
                details="Oracle procedure error"
            )
    except Exception as e:
        return ManualTriggerResponse(
            message="Failed to trigger health score calculation",
            success=False,
            details=str(e)
        )


@router.post("/run-forecast", response_model=ManualTriggerResponse)
async def trigger_forecast(user_id: int = Depends(get_current_user_id)):
    """Manually trigger monthly expense forecast."""
    from services.oracle_service import oracle_service
    
    try:
        success = oracle_service.predict_monthly_expenses(user_id)
        if success:
            return ManualTriggerResponse(
                message="Forecast calculation triggered successfully",
                success=True,
                details="Forecast will be available in BUDGET_FORECASTS table"
            )
        else:
            return ManualTriggerResponse(
                message="Failed to trigger forecast calculation",
                success=False,
                details="Oracle procedure error"
            )
    except Exception as e:
        return ManualTriggerResponse(
            message="Failed to trigger forecast calculation",
            success=False,
            details=str(e)
        )


@router.post("/run-recommendations", response_model=ManualTriggerResponse)
async def trigger_recommendations(user_id: int = Depends(get_current_user_id)):
    """Manually trigger smart recommendations generation."""
    from services.oracle_service import oracle_service
    
    try:
        success = oracle_service.generate_smart_recommendations(user_id)
        if success:
            return ManualTriggerResponse(
                message="Recommendations generation triggered successfully",
                success=True,
                details="Recommendations will be available in AI_RECOMMENDATIONS table"
            )
        else:
            return ManualTriggerResponse(
                message="Failed to trigger recommendations generation",
                success=False,
                details="Oracle procedure error"
            )
    except Exception as e:
        return ManualTriggerResponse(
            message="Failed to trigger recommendations generation",
            success=False,
            details=str(e)
        )


@router.post("/run-idle-detection", response_model=ManualTriggerResponse)
async def trigger_idle_detection(user_id: int = Depends(get_current_user_id)):
    """Manually trigger idle subscription detection."""
    from services.oracle_service import oracle_service
    
    try:
        success = oracle_service.process_idle_subscriptions(user_id)
        if success:
            return ManualTriggerResponse(
                message="Idle subscription detection triggered successfully",
                success=True,
                details="Signals will be available in BEHAVIORAL_SIGNALS table"
            )
        else:
            return ManualTriggerResponse(
                message="Failed to trigger idle detection",
                success=False,
                details="Oracle procedure error"
            )
    except Exception as e:
        return ManualTriggerResponse(
            message="Failed to trigger idle detection",
            success=False,
            details=str(e)
        )