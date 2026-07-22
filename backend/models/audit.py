"""
AURIXA Backend - Audit Log Models
Pydantic models for the AUDIT_LOG table
"""

from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime


class AuditLogResponse(BaseModel):
    log_id: int
    user_id: Optional[int] = None
    table_name: str
    operation: str
    record_id: Optional[int] = None
    old_values: Optional[str] = None
    new_values: Optional[str] = None
    performed_at: Optional[datetime] = None
    ip_address: Optional[str] = None
    session_id: Optional[str] = None


class AuditLogListResponse(BaseModel):
    logs: List[AuditLogResponse]
    total_count: int
    page: int
    page_size: int


class AuditSummaryResponse(BaseModel):
    total_entries: int
    insert_count: int
    update_count: int
    delete_count: int
    affected_tables: List[str]