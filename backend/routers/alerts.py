"""
AURIXA Backend - Alerts Routes
Handles risk alerts, notifications, and AI-powered anomaly detection
"""

from fastapi import APIRouter, HTTPException, Depends, Header, Query
from fastapi import status as http_status
from typing import List, Optional
from datetime import datetime, timedelta

from models.alert import (
    AlertResponse, AlertListResponse, AlertSummaryResponse, AlertSeverityCount,
    MarkAlertReadRequest, AnomalyDetectionResponse, NotificationResponse
)
from models.user import MessageResponse
from database import db
from auth import auth_manager

router = APIRouter(prefix="/api/alerts", tags=["Alerts"])


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


def get_subscription_name(sub_id: Optional[int]) -> Optional[str]:
    """Get subscription name by ID"""
    if not sub_id:
        return None
    result = db.execute_query(
        "SELECT service_name FROM SUBSCRIPTIONS WHERE sub_id = :sub_id",
        {"sub_id": sub_id}
    )
    return result[0][0] if result else None


# ========================================================================
# Alert Endpoints
# ========================================================================

@router.get("", response_model=AlertListResponse)
async def get_alerts(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    severity: Optional[str] = Query(None, pattern="^(LOW|MEDIUM|HIGH|CRITICAL)$"),
    alert_type: Optional[str] = None,
    unread_only: bool = Query(False),
    user_id: int = Depends(get_current_user_id)
):
    """Get paginated list of alerts for the user."""
    conditions = ["user_id = :user_id"]
    params = {"user_id": user_id, "limit": limit, "offset": offset}
    
    if severity:
        conditions.append("severity = :severity")
        params["severity"] = severity
    
    if alert_type:
        conditions.append("alert_type = :alert_type")
        params["alert_type"] = alert_type
    
    if unread_only:
        conditions.append("is_read = 'N'")
    
    where_clause = " AND ".join(conditions)
    
    alerts_result = db.execute_query(
        f"""SELECT alert_id, user_id, alert_type, severity, title, message,
                  related_sub_id, related_txn_id, is_read, triggered_at
           FROM RISK_ALERTS
           WHERE {where_clause}
           ORDER BY severity DESC, triggered_at DESC
           OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY""",
        params
    )
    
    count_params = {k: v for k, v in params.items() if k not in ["limit", "offset"]}
    total_result = db.execute_query(
        f"SELECT COUNT(*) FROM RISK_ALERTS WHERE {where_clause}",
        count_params
    )
    total_count = total_result[0][0] if total_result else 0
    
    unread_result = db.execute_query(
        "SELECT COUNT(*) FROM RISK_ALERTS WHERE user_id = :user_id AND is_read = 'N'",
        {"user_id": user_id}
    )
    unread_count = unread_result[0][0] if unread_result else 0
    
    alerts = []
    for row in alerts_result:
        (alert_id, user_id, alert_type, severity, title, message,
         related_sub_id, related_txn_id, is_read, triggered_at) = row
        
        alerts.append(AlertResponse(
            alert_id=alert_id,
            user_id=user_id,
            alert_type=alert_type,
            severity=severity,
            title=title,
            message=message,
            related_sub_id=related_sub_id,
            related_sub_name=get_subscription_name(related_sub_id),
            related_txn_id=related_txn_id,
            is_read=is_read == 'Y',
            triggered_at=triggered_at
        ))
    
    return AlertListResponse(
        alerts=alerts,
        total_count=total_count,
        unread_count=unread_count,
        page=offset // limit + 1 if limit > 0 else 1,
        page_size=limit
    )


@router.get("/summary", response_model=AlertSummaryResponse)
async def get_alert_summary(user_id: int = Depends(get_current_user_id)):
    """Get summary of alerts for dashboard display."""
    result = db.execute_query(
        "SELECT COUNT(*), SUM(CASE WHEN is_read = 'N' THEN 1 ELSE 0 END) "
        "FROM RISK_ALERTS WHERE user_id = :user_id",
        {"user_id": user_id}
    )
    total = result[0][0] if result else 0
    unread = result[0][1] if result and result[0][1] else 0
    
    severity_result = db.execute_query(
        """SELECT severity, COUNT(*) 
           FROM RISK_ALERTS 
           WHERE user_id = :user_id 
           GROUP BY severity""",
        {"user_id": user_id}
    )
    
    by_severity = []
    severity_map = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
    for row in severity_result:
        sev, cnt = row
        severity_map[sev] = cnt
    
    for sev, cnt in severity_map.items():
        by_severity.append(AlertSeverityCount(severity=sev, count=cnt))
    
    type_result = db.execute_query(
        """SELECT alert_type, COUNT(*) 
           FROM RISK_ALERTS 
           WHERE user_id = :user_id 
           GROUP BY alert_type""",
        {"user_id": user_id}
    )
    by_type = {row[0]: row[1] for row in type_result}
    
    return AlertSummaryResponse(
        total_alerts=total,
        unread_alerts=unread,
        critical_count=severity_map.get("CRITICAL", 0),
        high_count=severity_map.get("HIGH", 0),
        medium_count=severity_map.get("MEDIUM", 0),
        low_count=severity_map.get("LOW", 0),
        by_severity=by_severity,
        by_type=by_type
    )


@router.get("/{alert_id}", response_model=AlertResponse)
async def get_alert(alert_id: int, user_id: int = Depends(get_current_user_id)):
    """Get a single alert by ID."""
    result = db.execute_query(
        """SELECT alert_id, user_id, alert_type, severity, title, message,
                  related_sub_id, related_txn_id, is_read, triggered_at
           FROM RISK_ALERTS
           WHERE alert_id = :alert_id AND user_id = :user_id""",
        {"alert_id": alert_id, "user_id": user_id}
    )
    
    if not result:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )
    
    (alert_id, user_id, alert_type, severity, title, message,
     related_sub_id, related_txn_id, is_read, triggered_at) = result[0]
    
    return AlertResponse(
        alert_id=alert_id,
        user_id=user_id,
        alert_type=alert_type,
        severity=severity,
        title=title,
        message=message,
        related_sub_id=related_sub_id,
        related_sub_name=get_subscription_name(related_sub_id),
        related_txn_id=related_txn_id,
        is_read=is_read == 'Y',
        triggered_at=triggered_at
    )


@router.put("/{alert_id}/read", response_model=MessageResponse)
async def mark_alert_read(alert_id: int, user_id: int = Depends(get_current_user_id)):
    """Mark a single alert as read."""
    result = db.execute_query(
        "SELECT alert_id FROM RISK_ALERTS WHERE alert_id = :alert_id AND user_id = :user_id",
        {"alert_id": alert_id, "user_id": user_id}
    )
    
    if not result:
        raise HTTPException(
            status_code=http_status.HTTP_404_NOT_FOUND,
            detail="Alert not found"
        )
    
    db.execute_update(
        "UPDATE RISK_ALERTS SET is_read = 'Y' WHERE alert_id = :alert_id",
        {"alert_id": alert_id}
    )
    
    return MessageResponse(message="Alert marked as read")


@router.put("/mark-all-read", response_model=MessageResponse)
async def mark_all_alerts_read(user_id: int = Depends(get_current_user_id)):
    """Mark all alerts as read for the user."""
    db.execute_update(
        "UPDATE RISK_ALERTS SET is_read = 'Y' WHERE user_id = :user_id AND is_read = 'N'",
        {"user_id": user_id}
    )
    
    return MessageResponse(message="All alerts marked as read")


@router.post("/detect-anomalies", response_model=AnomalyDetectionResponse)
async def detect_anomalies(user_id: int = Depends(get_current_user_id)):
    """
    Trigger AI-powered anomaly detection using scikit-learn Isolation Forest.
    Integrated with services/ai_service.py
    """
    from services.ai_service import ai_service
    
    try:
        # Use AI service for anomaly detection
        anomalies = ai_service.detect_anomalies(user_id)
        
        if anomalies:
            # Flag anomalies in database
            flagged_count = ai_service.flag_anomalies_in_database(user_id)
            
            # Also create alerts for new anomalies
            for txn_id in anomalies:
                # Check if alert already exists for this transaction
                existing = db.execute_query(
                    "SELECT alert_id FROM RISK_ALERTS WHERE related_txn_id = :txn_id AND alert_type = 'ANOMALY'",
                    {"txn_id": txn_id}
                )
                
                if not existing:
                    # Get transaction details
                    txn_result = db.execute_query(
                        "SELECT amount, description FROM TRANSACTIONS WHERE txn_id = :txn_id",
                        {"txn_id": txn_id}
                    )
                    amount = float(txn_result[0][0]) if txn_result else 0
                    description = txn_result[0][1] if txn_result else "Unknown"
                    
                    db.execute_update(
                        """INSERT INTO RISK_ALERTS 
                           (alert_id, user_id, alert_type, severity, title, message, related_txn_id, triggered_at)
                           VALUES (SEQ_RISK_ALERTS.NEXTVAL, :user_id, 'ANOMALY', 'MEDIUM',
                                   'AI-Detected Unusual Transaction',
                                   :message, :txn_id, SYSDATE)""",
                        {
                            "user_id": user_id,
                            "message": f"AI detected an unusual transaction of ${amount:.2f} for '{description}'. This deviates from your normal spending pattern.",
                            "txn_id": txn_id
                        }
                    )
            
            return AnomalyDetectionResponse(
                anomalies_found=flagged_count,
                anomaly_ids=anomalies,
                message=f"AI detected {flagged_count} anomalous transactions using Isolation Forest",
                processed_at=datetime.now()
            )
        else:
            return AnomalyDetectionResponse(
                anomalies_found=0,
                anomaly_ids=[],
                message="No anomalies detected. All transactions appear normal.",
                processed_at=datetime.now()
            )
            
    except Exception as e:
        # Fallback to simple threshold detection if AI fails
        print(f"AI service error, falling back to threshold detection: {e}")
        return await _fallback_anomaly_detection(user_id)


async def _fallback_anomaly_detection(user_id: int) -> AnomalyDetectionResponse:
    """Fallback anomaly detection using simple threshold"""
    result = db.execute_query(
        """SELECT txn_id, amount, description
           FROM TRANSACTIONS
           WHERE user_id = :user_id
           AND txn_date >= SYSDATE - 30
           ORDER BY txn_date DESC
           FETCH FIRST 100 ROWS ONLY""",
        {"user_id": user_id}
    )
    
    anomalies = []
    if result and len(result) > 5:
        amounts = [float(row[1]) for row in result]
        avg_amount = sum(amounts) / len(amounts)
        threshold = avg_amount * 2.5
        
        for row in result:
            txn_id, amount, description = row
            if float(amount) > threshold:
                anomalies.append(txn_id)
                
                existing = db.execute_query(
                    "SELECT alert_id FROM RISK_ALERTS WHERE related_txn_id = :txn_id AND alert_type = 'ANOMALY'",
                    {"txn_id": txn_id}
                )
                
                if not existing:
                    db.execute_update(
                        """INSERT INTO RISK_ALERTS 
                           (alert_id, user_id, alert_type, severity, title, message, related_txn_id, triggered_at)
                           VALUES (SEQ_RISK_ALERTS.NEXTVAL, :user_id, 'ANOMALY', 'LOW',
                                   'Unusual Transaction Detected',
                                   :message, :txn_id, SYSDATE)""",
                        {
                            "user_id": user_id,
                            "message": f"Transaction of ${float(amount):.2f} is higher than your average (${avg_amount:.2f})",
                            "txn_id": txn_id
                        }
                    )
    
    return AnomalyDetectionResponse(
        anomalies_found=len(anomalies),
        anomaly_ids=anomalies,
        message=f"Threshold detection found {len(anomalies)} unusual transactions",
        processed_at=datetime.now()
    )


@router.get("/notifications", response_model=List[NotificationResponse])
async def get_notifications(
    limit: int = Query(50, ge=1, le=200),
    user_id: int = Depends(get_current_user_id)
):
    """Get user's notification history."""
    result = db.execute_query(
        """SELECT n.notif_id, n.user_id, n.alert_id, a.title, n.channel, n.status, n.sent_at, n.delivered_at
           FROM NOTIFICATION_LOG n
           LEFT JOIN RISK_ALERTS a ON n.alert_id = a.alert_id
           WHERE n.user_id = :user_id
           ORDER BY n.sent_at DESC
           FETCH FIRST :limit ROWS ONLY""",
        {"user_id": user_id, "limit": limit}
    )
    
    notifications = []
    for row in result:
        notif_id, user_id, alert_id, alert_title, channel, status, sent_at, delivered_at = row
        notifications.append(NotificationResponse(
            notif_id=notif_id,
            user_id=user_id,
            alert_id=alert_id,
            alert_title=alert_title,
            channel=channel,
            status=status,
            sent_at=sent_at,
            delivered_at=delivered_at
        ))
    
    return notifications