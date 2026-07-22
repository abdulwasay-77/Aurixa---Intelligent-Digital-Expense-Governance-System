"""
AURIXA Backend - Audit Trail Router
Read-only access to AUDIT_LOG for the authenticated user.

Endpoints:
  GET /api/audit          — paginated audit log list (filter by operation / table)
  GET /api/audit/summary  — counts by operation type + distinct tables
"""

from fastapi import APIRouter, HTTPException, Depends, Header, Query
from fastapi import status as http_status
from typing import Optional

from models.audit import AuditLogResponse, AuditLogListResponse, AuditSummaryResponse
from database import db
from auth import auth_manager

router = APIRouter(prefix="/api/audit", tags=["Audit Trail"])


# ============================================================================
# Auth Helper (same pattern as every other router)
# ============================================================================

async def get_current_user_id(authorization: str = Header(None)):
    """Extract user_id from JWT Bearer token."""
    if not authorization:
        raise HTTPException(
            status_code=http_status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header",
        )
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=http_status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Use 'Bearer <token>'",
        )
    token = parts[1]
    user_id = auth_manager.get_user_id_from_token(token)
    if not user_id:
        raise HTTPException(
            status_code=http_status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    return user_id


# ============================================================================
# Endpoints
# ============================================================================

@router.get("", response_model=AuditLogListResponse)
async def get_audit_logs(
    operation: Optional[str] = Query(None, description="Filter by operation: INSERT, UPDATE, DELETE"),
    table_name: Optional[str] = Query(None, description="Filter by table name, e.g. SUBSCRIPTIONS"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user_id: int = Depends(get_current_user_id),
):
    """
    Return a paginated list of AUDIT_LOG rows for the authenticated user.
    Supports optional filtering by operation type and table name.
    """

    # Build dynamic WHERE clause
    conditions = ["user_id = :user_id"]
    params: dict = {"user_id": user_id}

    if operation:
        conditions.append("OPERATION = :operation")
        params["operation"] = operation.upper()

    if table_name:
        conditions.append("TABLE_NAME = :table_name")
        params["table_name"] = table_name.upper()

    where_clause = " AND ".join(conditions)

    # Total count
    count_result = db.execute_query(
        f"SELECT COUNT(*) FROM AUDIT_LOG WHERE {where_clause}",
        params,
    )
    total_count = int(count_result[0][0]) if count_result else 0

    # Paginated rows — Oracle 21c uses OFFSET…FETCH
    params["limit"] = limit
    params["offset"] = offset

    rows = db.execute_query(
        f"""
        SELECT log_id, user_id, table_name, operation, record_id,
               old_values, new_values, performed_at, ip_address, session_id
        FROM AUDIT_LOG
        WHERE {where_clause}
        ORDER BY performed_at DESC, log_id DESC
        OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY
        """,
        params,
    )

    logs = []
    for row in (rows or []):
        (
            log_id, uid, tbl, op, rec_id,
            old_vals, new_vals, performed_at, ip, session,
        ) = row
        logs.append(
            AuditLogResponse(
                log_id=int(log_id),
                user_id=int(uid) if uid is not None else None,
                table_name=str(tbl),
                operation=str(op),
                record_id=int(rec_id) if rec_id is not None else None,
                old_values=str(old_vals) if old_vals is not None else None,
                new_values=str(new_vals) if new_vals is not None else None,
                performed_at=performed_at,
                ip_address=str(ip) if ip is not None else None,
                session_id=str(session) if session is not None else None,
            )
        )

    return AuditLogListResponse(
        logs=logs,
        total_count=total_count,
        page=(offset // limit) + 1,
        page_size=limit,
    )


@router.get("/summary", response_model=AuditSummaryResponse)
async def get_audit_summary(user_id: int = Depends(get_current_user_id)):
    """
    Return operation-type counts and the list of distinct affected tables
    for the authenticated user's audit history.
    """

    count_rows = db.execute_query(
        """
        SELECT operation, COUNT(*) as cnt
        FROM AUDIT_LOG
        WHERE user_id = :user_id
        GROUP BY operation
        """,
        {"user_id": user_id},
    )

    total = 0
    insert_count = 0
    update_count = 0
    delete_count = 0

    for row in (count_rows or []):
        op, cnt = row
        cnt = int(cnt)
        total += cnt
        if op == "INSERT":
            insert_count = cnt
        elif op == "UPDATE":
            update_count = cnt
        elif op == "DELETE":
            delete_count = cnt

    table_rows = db.execute_query(
        """
        SELECT DISTINCT table_name
        FROM AUDIT_LOG
        WHERE user_id = :user_id
        ORDER BY table_name
        """,
        {"user_id": user_id},
    )

    affected_tables = [str(r[0]) for r in (table_rows or [])]

    return AuditSummaryResponse(
        total_entries=total,
        insert_count=insert_count,
        update_count=update_count,
        delete_count=delete_count,
        affected_tables=affected_tables,
    )