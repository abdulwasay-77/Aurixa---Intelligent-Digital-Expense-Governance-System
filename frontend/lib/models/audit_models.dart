/// AURIXA — Audit Trail Models
/// Mirrors the /api/audit backend responses.
library;

// ============================================================================
// AuditLogResponse
// ============================================================================

class AuditLogResponse {
  final int logId;
  final int? userId;
  final String tableName;
  final String operation;
  final int? recordId;
  final String? oldValues;
  final String? newValues;
  final DateTime? performedAt;
  final String? ipAddress;
  final String? sessionId;

  const AuditLogResponse({
    required this.logId,
    this.userId,
    required this.tableName,
    required this.operation,
    this.recordId,
    this.oldValues,
    this.newValues,
    this.performedAt,
    this.ipAddress,
    this.sessionId,
  });

  factory AuditLogResponse.fromJson(Map<String, dynamic> json) {
    return AuditLogResponse(
      logId: json['log_id'] as int,
      userId: json['user_id'] as int?,
      tableName: json['table_name'] as String,
      operation: json['operation'] as String,
      recordId: json['record_id'] as int?,
      oldValues: json['old_values'] as String?,
      newValues: json['new_values'] as String?,
      performedAt: json['performed_at'] != null
          ? DateTime.tryParse(json['performed_at'] as String)
          : null,
      ipAddress: json['ip_address'] as String?,
      sessionId: json['session_id'] as String?,
    );
  }
}

// ============================================================================
// AuditLogListResponse
// ============================================================================

class AuditLogListResponse {
  final List<AuditLogResponse> logs;
  final int totalCount;
  final int page;
  final int pageSize;

  const AuditLogListResponse({
    required this.logs,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory AuditLogListResponse.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['logs'] as List<dynamic>? ?? [];
    return AuditLogListResponse(
      logs: rawLogs
          .map((e) => AuditLogResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['total_count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }
}

// ============================================================================
// AuditSummaryResponse
// ============================================================================

class AuditSummaryResponse {
  final int totalEntries;
  final int insertCount;
  final int updateCount;
  final int deleteCount;
  final List<String> affectedTables;

  const AuditSummaryResponse({
    required this.totalEntries,
    required this.insertCount,
    required this.updateCount,
    required this.deleteCount,
    required this.affectedTables,
  });

  factory AuditSummaryResponse.fromJson(Map<String, dynamic> json) {
    final rawTables = json['affected_tables'] as List<dynamic>? ?? [];
    return AuditSummaryResponse(
      totalEntries: json['total_entries'] as int? ?? 0,
      insertCount: json['insert_count'] as int? ?? 0,
      updateCount: json['update_count'] as int? ?? 0,
      deleteCount: json['delete_count'] as int? ?? 0,
      affectedTables: rawTables.map((e) => e as String).toList(),
    );
  }
}