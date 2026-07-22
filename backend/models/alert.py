"""
AURIXA Backend - Alert Pydantic Models
Request and response schemas for Alert management
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ========================================================================
# Alert Models
# ========================================================================

class AlertResponse(BaseModel):
    """Response model for a single alert"""
    alert_id: int
    user_id: int
    alert_type: str  # BUDGET_BREACH, ANOMALY, PRICE_CHANGE, IDLE_SUB, DUPLICATE
    severity: str  # LOW, MEDIUM, HIGH, CRITICAL
    title: str
    message: str
    related_sub_id: Optional[int] = None
    related_sub_name: Optional[str] = None
    related_txn_id: Optional[int] = None
    is_read: bool
    triggered_at: datetime


class AlertListResponse(BaseModel):
    """Response model for paginated alert list"""
    alerts: List[AlertResponse]
    total_count: int
    unread_count: int
    page: int
    page_size: int


class AlertSeverityCount(BaseModel):
    """Count of alerts by severity"""
    severity: str
    count: int


class AlertSummaryResponse(BaseModel):
    """Summary of alerts for dashboard"""
    total_alerts: int
    unread_alerts: int
    critical_count: int
    high_count: int
    medium_count: int
    low_count: int
    by_severity: List[AlertSeverityCount]
    by_type: dict


class MarkAlertReadRequest(BaseModel):
    """Request model for marking alerts as read"""
    alert_ids: Optional[List[int]] = None  # If None, mark all as read


# ========================================================================
# Anomaly Detection Models
# ========================================================================

class AnomalyDetectionRequest(BaseModel):
    """Request model for triggering anomaly detection"""
    transaction_ids: Optional[List[int]] = None  # If None, check recent transactions


class AnomalyDetectionResponse(BaseModel):
    """Response model for anomaly detection results"""
    anomalies_found: int
    anomaly_ids: List[int]
    message: str
    processed_at: datetime


# ========================================================================
# Notification Models
# ========================================================================

class NotificationResponse(BaseModel):
    """Response model for notification log entry"""
    notif_id: int
    user_id: int
    alert_id: Optional[int]
    alert_title: Optional[str]
    channel: str  # IN_APP, PUSH, EMAIL
    status: str  # SENT, DELIVERED, FAILED, READ
    sent_at: datetime
    delivered_at: Optional[datetime] = None


class NotificationPreferences(BaseModel):
    """User notification preferences"""
    budget_alerts: bool = True
    billing_reminders: bool = True
    anomaly_alerts: bool = True
    price_change_alerts: bool = True
    idle_sub_alerts: bool = True
    email_notifications: bool = False
    push_notifications: bool = False