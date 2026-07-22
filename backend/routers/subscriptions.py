"""
AURIXA Backend - Subscription Routes
Handles subscription CRUD operations with Oracle Service integration
"""

from fastapi import APIRouter, HTTPException, Depends, Header
from fastapi import status as http_status
from typing import Optional, List
from datetime import date, datetime

from models.subscription import (
    CreateSubscriptionRequest, UpdateSubscriptionRequest, UpdateUsageScoreRequest,
    SubscriptionResponse, SubscriptionListResponse, IdleSubscriptionResponse
)
from models.user import MessageResponse
from database import db
from auth import auth_manager
from services.oracle_service import oracle_service

router = APIRouter(prefix="/api/subscriptions", tags=["Subscriptions"])


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


def get_currency_id(currency_code: str) -> int:
    """Get currency_id from currency code"""
    result = db.execute_query(
        "SELECT currency_id FROM CURRENCIES WHERE code = :code",
        {"code": currency_code}
    )
    if not result:
        raise HTTPException(status_code=400, detail=f"Invalid currency code: {currency_code}")
    return result[0][0]


def get_currency_info(currency_id: int) -> tuple:
    """Get currency code and symbol"""
    result = db.execute_query(
        "SELECT code, symbol FROM CURRENCIES WHERE currency_id = :currency_id",
        {"currency_id": currency_id}
    )
    if not result:
        return "USD", "$"
    return result[0][0], result[0][1]


def get_category_id(category_name: str) -> tuple:
    """Get category_id from category name"""
    result = db.execute_query(
        "SELECT category_id, icon_code, color_hex FROM EXPENSE_CATEGORIES WHERE name = :name",
        {"name": category_name}
    )
    if not result:
        raise HTTPException(status_code=400, detail=f"Invalid category name: {category_name}")
    return result[0][0], result[0][1], result[0][2]


def get_or_create_vendor_id(vendor_name: str, category_id: int) -> Optional[int]:
    """Get existing vendor ID or create new one"""
    if not vendor_name:
        return None

    # Check if vendor exists
    result = db.execute_query(
        "SELECT vendor_id FROM SUBSCRIPTION_VENDORS WHERE vendor_name = :vendor_name",
        {"vendor_name": vendor_name}
    )

    if result:
        return result[0][0]

    # Create new vendor
    try:
        db.execute_update(
            """INSERT INTO SUBSCRIPTION_VENDORS
               (vendor_id, vendor_name, category_id, country_code)
               VALUES (SEQ_VENDORS.NEXTVAL, :vendor_name, :category_id, 'US')""",
            {"vendor_name": vendor_name, "category_id": category_id}
        )

        result = db.execute_query(
            "SELECT vendor_id FROM SUBSCRIPTION_VENDORS WHERE vendor_name = :vendor_name",
            {"vendor_name": vendor_name}
        )
        return result[0][0] if result else None
    except Exception:
        return None


def get_subscription_by_id(sub_id: int, user_id: int):
    """Get subscription by ID and verify ownership"""
    result = db.execute_query(
        """SELECT s.sub_id, s.user_id, s.vendor_id, v.vendor_name,
                  s.category_id, ec.name as category_name, ec.icon_code, ec.color_hex,
                  s.currency_id, c.code, c.symbol,
                  s.service_name, s.billing_amount, s.billing_cycle,
                  s.next_billing_date, s.start_date, s.usage_score, s.status, s.notes, s.created_at
           FROM SUBSCRIPTIONS s
           LEFT JOIN SUBSCRIPTION_VENDORS v ON s.vendor_id = v.vendor_id
           JOIN EXPENSE_CATEGORIES ec ON s.category_id = ec.category_id
           JOIN CURRENCIES c ON s.currency_id = c.currency_id
           WHERE s.sub_id = :sub_id AND s.user_id = :user_id""",
        {"sub_id": sub_id, "user_id": user_id}
    )
    return result[0] if result else None


def calculate_total_spent(sub_id: int) -> float:
    """Calculate total amount spent on a subscription"""
    result = db.execute_query(
        "SELECT NVL(SUM(amount_charged), 0) FROM BILLING_CYCLES WHERE sub_id = :sub_id AND status = 'PAID'",
        {"sub_id": sub_id}
    )
    return float(result[0][0]) if result else 0.0


def count_upcoming_billing(sub_id: int) -> int:
    """Count upcoming scheduled billing cycles"""
    result = db.execute_query(
        "SELECT COUNT(*) FROM BILLING_CYCLES WHERE sub_id = :sub_id AND status = 'SCHEDULED'",
        {"sub_id": sub_id}
    )
    return result[0][0] if result else 0


# ========================================================================
# API Endpoints
# ========================================================================

@router.get("", response_model=SubscriptionListResponse)
async def get_subscriptions(user_id: int = Depends(get_current_user_id)):
    """
    Get all subscriptions for the authenticated user.
    """
    # Get all subscriptions
    result = db.execute_query(
        """SELECT s.sub_id, s.user_id, s.vendor_id, v.vendor_name,
                  s.category_id, ec.name as category_name, ec.icon_code, ec.color_hex,
                  s.currency_id, c.code, c.symbol,
                  s.service_name, s.billing_amount, s.billing_cycle,
                  s.next_billing_date, s.start_date, s.usage_score, s.status, s.notes, s.created_at
           FROM SUBSCRIPTIONS s
           LEFT JOIN SUBSCRIPTION_VENDORS v ON s.vendor_id = v.vendor_id
           JOIN EXPENSE_CATEGORIES ec ON s.category_id = ec.category_id
           JOIN CURRENCIES c ON s.currency_id = c.currency_id
           WHERE s.user_id = :user_id
           ORDER BY s.billing_amount DESC""",
        {"user_id": user_id}
    )

    subscriptions = []
    total_monthly_spend = 0.0
    active_count = 0

    for row in result:
        (sub_id, user_id, vendor_id, vendor_name, category_id, category_name,
         icon_code, color_hex, currency_id, currency_code, currency_symbol,
         service_name, billing_amount, billing_cycle, next_billing_date,
         start_date, usage_score, status_val, notes, created_at) = row

        # Calculate monthly equivalent for total spend
        monthly_amount = float(billing_amount)
        if billing_cycle == 'YEARLY':
            monthly_amount = billing_amount / 12
        elif billing_cycle == 'QUARTERLY':
            monthly_amount = billing_amount / 3
        elif billing_cycle == 'WEEKLY':
            monthly_amount = billing_amount * 4.33

        if status_val == 'ACTIVE':
            total_monthly_spend += monthly_amount
            active_count += 1

        subscriptions.append(SubscriptionResponse(
            sub_id=sub_id,
            user_id=user_id,
            vendor_id=vendor_id,
            vendor_name=vendor_name,
            category_id=category_id,
            category_name=category_name,
            category_icon=icon_code,
            category_color=color_hex,
            currency_code=currency_code,
            currency_symbol=currency_symbol,
            service_name=service_name,
            billing_amount=float(billing_amount),
            billing_cycle=billing_cycle,
            next_billing_date=next_billing_date,
            start_date=start_date,
            usage_score=usage_score,
            status=status_val,
            notes=notes,
            created_at=created_at,
            total_spent=calculate_total_spent(sub_id),
            upcoming_billing_count=count_upcoming_billing(sub_id)
        ))

    return SubscriptionListResponse(
        subscriptions=subscriptions,
        total_count=len(subscriptions),
        active_count=active_count,
        total_monthly_spend=round(total_monthly_spend, 2)
    )


@router.get("/{sub_id}", response_model=SubscriptionResponse)
async def get_subscription(sub_id: int, user_id: int = Depends(get_current_user_id)):
    """
    Get a single subscription by ID.
    """
    subscription = get_subscription_by_id(sub_id, user_id)

    if not subscription:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Subscription not found"
        )

    (sub_id, user_id, vendor_id, vendor_name, category_id, category_name,
     icon_code, color_hex, currency_id, currency_code, currency_symbol,
     service_name, billing_amount, billing_cycle, next_billing_date,
     start_date, usage_score, status_val, notes, created_at) = subscription

    return SubscriptionResponse(
        sub_id=sub_id,
        user_id=user_id,
        vendor_id=vendor_id,
        vendor_name=vendor_name,
        category_id=category_id,
        category_name=category_name,
        category_icon=icon_code,
        category_color=color_hex,
        currency_code=currency_code,
        currency_symbol=currency_symbol,
        service_name=service_name,
        billing_amount=float(billing_amount),
        billing_cycle=billing_cycle,
        next_billing_date=next_billing_date,
        start_date=start_date,
        usage_score=usage_score,
        status=status_val,
        notes=notes,
        created_at=created_at,
        total_spent=calculate_total_spent(sub_id),
        upcoming_billing_count=count_upcoming_billing(sub_id)
    )


@router.post("", response_model=SubscriptionResponse, status_code=http_status.HTTP_201_CREATED)
async def create_subscription(request: CreateSubscriptionRequest, user_id: int = Depends(get_current_user_id)):
    """
    Create a new subscription with billing schedule generation.
    Integrated with services/oracle_service.py

    *** FIX 2 ***
    Previously, a failure in oracle_service.generate_billing_schedule() was
    caught here, printed to the console, and ignored — the function returned
    HTTP 201 with a "successfully created" subscription that secretly had
    zero rows in BILLING_CYCLES (this is exactly what happened with sub 16
    and sub 17 / Claude Premium).

    Now: if billing schedule generation fails, the subscription row itself
    is deleted and the endpoint returns a 500 with a clear message. Either
    both the subscription AND its billing history exist, or neither does —
    no more orphaned subscriptions.
    """
    # Get category
    category_id, icon_code, color_hex = get_category_id(request.category_name)

    # Get currency
    currency_id = get_currency_id(request.currency_code)

    # Get or create vendor
    vendor_id = get_or_create_vendor_id(request.vendor_name, category_id) if request.vendor_name else None

    # Insert subscription
    try:
        db.execute_update(
            """INSERT INTO SUBSCRIPTIONS
               (sub_id, user_id, vendor_id, category_id, currency_id,
                service_name, billing_amount, billing_cycle, next_billing_date,
                start_date, usage_score, status, notes, created_at)
               VALUES (SEQ_SUBSCRIPTIONS.NEXTVAL, :user_id, :vendor_id, :category_id, :currency_id,
                       :service_name, :billing_amount, :billing_cycle, :next_billing_date,
                       :start_date, :usage_score, 'ACTIVE', :notes, SYSDATE)""",
            {
                "user_id": user_id,
                "vendor_id": vendor_id,
                "category_id": category_id,
                "currency_id": currency_id,
                "service_name": request.service_name,
                "billing_amount": request.billing_amount,
                "billing_cycle": request.billing_cycle,
                "next_billing_date": request.next_billing_date,
                "start_date": request.start_date,
                "usage_score": request.usage_score,
                "notes": request.notes
            }
        )

        # Get the created subscription
        result = db.execute_query(
            """SELECT sub_id FROM SUBSCRIPTIONS
               WHERE user_id = :user_id AND service_name = :service_name
               ORDER BY sub_id DESC FETCH FIRST 1 ROW ONLY""",
            {"user_id": user_id, "service_name": request.service_name}
        )

        if not result:
            raise HTTPException(status_code=500, detail="Failed to create subscription")

        new_sub_id = result[0][0]

        # *** FIX 2 *** Call stored procedure to generate billing schedule.
        # oracle_service.generate_billing_schedule() now raises on failure
        # instead of swallowing the error, so this except block actually
        # sees real Oracle errors and can react to them.
        try:
            oracle_service.generate_billing_schedule(new_sub_id, 12)
        except Exception as e:
            # Roll the orphaned subscription back out rather than leaving a
            # subscription with no billing history. The DB stays consistent:
            # either both exist, or neither does.
            db.execute_update(
                "DELETE FROM SUBSCRIPTIONS WHERE sub_id = :sub_id",
                {"sub_id": new_sub_id}
            )
            raise HTTPException(
                status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Subscription was not created: billing schedule generation failed "
                       f"({str(e)}). Please try again."
            )

        # Return the created subscription
        return await get_subscription(new_sub_id, user_id)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create subscription: {str(e)}"
        )


@router.put("/{sub_id}", response_model=SubscriptionResponse)
async def update_subscription(sub_id: int, request: UpdateSubscriptionRequest, user_id: int = Depends(get_current_user_id)):
    """
    Update an existing subscription.
    """
    # Verify ownership
    existing = get_subscription_by_id(sub_id, user_id)
    if not existing:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Subscription not found"
        )

    # Build dynamic update query
    updates = []
    params = {"sub_id": sub_id}

    if request.vendor_name is not None:
        category_id = existing[4]  # category_id from existing
        vendor_id = get_or_create_vendor_id(request.vendor_name, category_id)
        updates.append("vendor_id = :vendor_id")
        params["vendor_id"] = vendor_id

    if request.category_name is not None:
        category_id, _, _ = get_category_id(request.category_name)
        updates.append("category_id = :category_id")
        params["category_id"] = category_id

    if request.service_name is not None:
        updates.append("service_name = :service_name")
        params["service_name"] = request.service_name

    if request.billing_amount is not None:
        updates.append("billing_amount = :billing_amount")
        params["billing_amount"] = request.billing_amount

    if request.billing_cycle is not None:
        updates.append("billing_cycle = :billing_cycle")
        params["billing_cycle"] = request.billing_cycle

    if request.next_billing_date is not None:
        updates.append("next_billing_date = :next_billing_date")
        params["next_billing_date"] = request.next_billing_date

    if request.usage_score is not None:
        updates.append("usage_score = :usage_score")
        params["usage_score"] = request.usage_score

    if request.status is not None:
        updates.append("status = :status")
        params["status"] = request.status

    if request.notes is not None:
        updates.append("notes = :notes")
        params["notes"] = request.notes

    if updates:
        query = f"UPDATE SUBSCRIPTIONS SET {', '.join(updates)} WHERE sub_id = :sub_id"
        try:
            db.execute_update(query, params)
        except Exception as e:
            raise HTTPException(
                status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to update subscription: {str(e)}"
            )

    # Return updated subscription
    return await get_subscription(sub_id, user_id)


@router.delete("/{sub_id}", response_model=MessageResponse)
async def delete_subscription(sub_id: int, user_id: int = Depends(get_current_user_id)):
    """
    Cancel/Delete a subscription.
    Sets status to 'CANCELLED' (soft delete).
    """
    # Verify ownership
    existing = get_subscription_by_id(sub_id, user_id)
    if not existing:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Subscription not found"
        )

    # Soft delete - set status to CANCELLED
    try:
        db.execute_update(
            "UPDATE SUBSCRIPTIONS SET status = 'CANCELLED' WHERE sub_id = :sub_id",
            {"sub_id": sub_id}
        )
        return MessageResponse(message="Subscription cancelled successfully")
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to cancel subscription: {str(e)}"
        )


@router.patch("/{sub_id}/usage", response_model=MessageResponse)
async def update_usage_score(sub_id: int, request: UpdateUsageScoreRequest, user_id: int = Depends(get_current_user_id)):
    """
    Update usage score for a subscription.
    """
    # Verify ownership
    existing = get_subscription_by_id(sub_id, user_id)
    if not existing:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Subscription not found"
        )

    try:
        db.execute_update(
            "UPDATE SUBSCRIPTIONS SET usage_score = :usage_score WHERE sub_id = :sub_id",
            {"usage_score": request.usage_score, "sub_id": sub_id}
        )
        return MessageResponse(message="Usage score updated successfully")
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update usage score: {str(e)}"
        )


@router.get("/idle/detection", response_model=List[IdleSubscriptionResponse])
async def detect_idle_subscriptions(user_id: int = Depends(get_current_user_id)):
    """
    Detect idle subscriptions based on usage score.
    """
    result = db.execute_query(
        """SELECT sub_id, service_name, billing_amount, usage_score
           FROM SUBSCRIPTIONS
           WHERE user_id = :user_id AND status = 'ACTIVE'
           ORDER BY usage_score ASC, billing_amount DESC""",
        {"user_id": user_id}
    )

    idle_subscriptions = []

    for row in result:
        sub_id, service_name, billing_amount, usage_score = row

        # Determine recommendation based on usage score
        if usage_score <= 2:
            recommendation = "Consider cancelling - very low usage"
        elif usage_score <= 4:
            recommendation = "Review usage - consider downgrading"
        elif usage_score <= 6:
            recommendation = "Moderate usage - monitor"
        else:
            recommendation = "Good usage - keep"

        idle_subscriptions.append(IdleSubscriptionResponse(
            sub_id=sub_id,
            service_name=service_name,
            billing_amount=float(billing_amount),
            usage_score=usage_score,
            days_since_use=None,
            recommendation=recommendation
        ))

    return idle_subscriptions


@router.get("/categories/summary", response_model=List[dict])
async def get_category_summary(user_id: int = Depends(get_current_user_id)):
    """
    Get spending summary by category.
    """
    result = db.execute_query(
        """SELECT ec.name as category_name,
                  COUNT(s.sub_id) as subscription_count,
                  SUM(s.billing_amount) as total_monthly
           FROM SUBSCRIPTIONS s
           JOIN EXPENSE_CATEGORIES ec ON s.category_id = ec.category_id
           WHERE s.user_id = :user_id AND s.status = 'ACTIVE'
           GROUP BY ec.name
           ORDER BY total_monthly DESC""",
        {"user_id": user_id}
    )

    categories = []
    for row in result:
        categories.append({
            "category_name": row[0],
            "subscription_count": row[1],
            "total_monthly": float(row[2]) if row[2] else 0
        })

    return categories


@router.post("/process-idle", response_model=MessageResponse)
async def process_idle_subscriptions(user_id: int = Depends(get_current_user_id)):
    """
    Manually trigger idle subscription processing using Oracle Service.
    Integrated with services/oracle_service.py
    """
    try:
        success = oracle_service.process_idle_subscriptions(user_id)
        if success:
            return MessageResponse(message="Idle subscriptions processed successfully")
        else:
            return MessageResponse(message="Failed to process idle subscriptions", success=False)
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process idle subscriptions: {str(e)}"
        )


@router.post("/generate-billing/{sub_id}", response_model=MessageResponse)
async def generate_billing_schedule(sub_id: int, months: int = 12, user_id: int = Depends(get_current_user_id)):
    """
    Manually generate billing schedule for a subscription using Oracle Service.
    Integrated with services/oracle_service.py
    """
    # Verify ownership
    existing = get_subscription_by_id(sub_id, user_id)
    if not existing:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Subscription not found"
        )

    try:
        success = oracle_service.generate_billing_schedule(sub_id, months)
        if success:
            return MessageResponse(message=f"Billing schedule generated for {months} months")
        else:
            return MessageResponse(message="Failed to generate billing schedule", success=False)
    except Exception as e:
        raise HTTPException(
            status_code=http_status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate billing schedule: {str(e)}"
        )