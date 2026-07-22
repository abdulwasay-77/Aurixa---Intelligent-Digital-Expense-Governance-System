/// Alert Models — RiskRadar alert responses
library;

// ============================================================================
// Alert Response Model
// ============================================================================

class AlertResponse {
  final int alertId;
  final int userId;
  final String alertType;
  final String severity;
  final String title;
  final String message;
  final int? relatedSubId;
  final String? relatedSubName;
  final int? relatedTxnId;
  final bool isRead;
  final DateTime triggeredAt;

  AlertResponse({
    required this.alertId,
    required this.userId,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.message,
    this.relatedSubId,
    this.relatedSubName,
    this.relatedTxnId,
    required this.isRead,
    required this.triggeredAt,
  });

  factory AlertResponse.fromJson(Map<String, dynamic> json) {
    return AlertResponse(
      alertId: json['alert_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      alertType: json['alert_type'] ?? '',
      severity: json['severity'] ?? 'MEDIUM',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      relatedSubId: json['related_sub_id'],
      relatedSubName: json['related_sub_name'],
      relatedTxnId: json['related_txn_id'],
      isRead: json['is_read'] ?? false,
      triggeredAt: json['triggered_at'] != null
          ? DateTime.parse(json['triggered_at'])
          : DateTime.now(),
    );
  }

  String get severityLabel {
    switch (severity) {
      case 'CRITICAL': return 'Critical';
      case 'HIGH': return 'High';
      case 'MEDIUM': return 'Medium';
      case 'LOW': return 'Low';
      default: return severity;
    }
  }

  String get alertTypeLabel {
    switch (alertType) {
      case 'BUDGET_BREACH': return 'Budget Breach';
      case 'PRICE_CHANGE': return 'Price Change';
      case 'ANOMALY': return 'Anomaly';
      case 'IDLE_SUB': return 'Idle Subscription';
      case 'DUPLICATE': return 'Duplicate';
      default: return alertType;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(triggeredAt);

    if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30} months ago';
    }
    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7} weeks ago';
    }
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    }
    return 'Just now';
  }
}

// ============================================================================
// Alert List Response Model
// ============================================================================

class AlertListResponse {
  final List<AlertResponse> alerts;
  final int totalCount;
  final int unreadCount;
  final int page;
  final int pageSize;

  AlertListResponse({
    required this.alerts,
    required this.totalCount,
    required this.unreadCount,
    required this.page,
    required this.pageSize,
  });

  factory AlertListResponse.fromJson(Map<String, dynamic> json) {
    final alerts = json['alerts'] as List? ?? [];
    return AlertListResponse(
      alerts: alerts.map((a) => AlertResponse.fromJson(a)).toList(),
      totalCount: json['total_count'] ?? 0,
      unreadCount: json['unread_count'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 20,
    );
  }
}

// ============================================================================
// Alert Summary Response Model
// ============================================================================

class AlertSeverityCount {
  final String severity;
  final int count;

  AlertSeverityCount({
    required this.severity,
    required this.count,
  });

  factory AlertSeverityCount.fromJson(Map<String, dynamic> json) {
    return AlertSeverityCount(
      severity: json['severity'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class AlertSummaryResponse {
  final int totalAlerts;
  final int unreadAlerts;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final List<AlertSeverityCount> bySeverity;
  final Map<String, int> byType;

  AlertSummaryResponse({
    required this.totalAlerts,
    required this.unreadAlerts,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.bySeverity,
    required this.byType,
  });

  factory AlertSummaryResponse.fromJson(Map<String, dynamic> json) {
    final bySeverity = json['by_severity'] as List? ?? [];
    return AlertSummaryResponse(
      totalAlerts: json['total_alerts'] ?? 0,
      unreadAlerts: json['unread_alerts'] ?? 0,
      criticalCount: json['critical_count'] ?? 0,
      highCount: json['high_count'] ?? 0,
      mediumCount: json['medium_count'] ?? 0,
      lowCount: json['low_count'] ?? 0,
      bySeverity: bySeverity.map((s) => AlertSeverityCount.fromJson(s)).toList(),
      byType: json['by_type'] != null
          ? Map<String, int>.from(json['by_type'])
          : {},
    );
  }
}

// ============================================================================
// Anomaly Detection Response
// ============================================================================

class AnomalyDetectionResponse {
  final int anomaliesFound;
  final List<int> anomalyIds;
  final String message;
  final DateTime processedAt;

  AnomalyDetectionResponse({
    required this.anomaliesFound,
    required this.anomalyIds,
    required this.message,
    required this.processedAt,
  });

  factory AnomalyDetectionResponse.fromJson(Map<String, dynamic> json) {
    return AnomalyDetectionResponse(
      anomaliesFound: json['anomalies_found'] ?? 0,
      anomalyIds: json['anomaly_ids'] != null
          ? List<int>.from(json['anomaly_ids'])
          : [],
      message: json['message'] ?? '',
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : DateTime.now(),
    );
  }
}