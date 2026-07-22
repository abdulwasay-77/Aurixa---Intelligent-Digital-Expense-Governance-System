/// Analytics Models — Score, Forecast, Insights, Categories, Patterns
library;

import 'package:flutter/material.dart';

// ============================================================================
// Financial Score Models
// ============================================================================

class FinancialScoreResponse {
  final int scoreId;
  final int userId;
  final DateTime scoreDate;
  final double financialHealthScore;
  final double? savingsRateScore;
  final double? budgetDisciplineScore;
  final double? subDependencyRatio;
  final double? riskFactorScore;
  final String scoreLabel;

  FinancialScoreResponse({
    required this.scoreId,
    required this.userId,
    required this.scoreDate,
    required this.financialHealthScore,
    this.savingsRateScore,
    this.budgetDisciplineScore,
    this.subDependencyRatio,
    this.riskFactorScore,
    required this.scoreLabel,
  });

  factory FinancialScoreResponse.fromJson(Map<String, dynamic> json) {
    return FinancialScoreResponse(
      scoreId: json['score_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      scoreDate: json['score_date'] != null
          ? DateTime.parse(json['score_date'])
          : DateTime.now(),
      financialHealthScore: (json['financial_health_score'] ?? 50).toDouble(),
      savingsRateScore: json['savings_rate_score']?.toDouble(),
      budgetDisciplineScore: json['budget_discipline_score']?.toDouble(),
      subDependencyRatio: json['sub_dependency_ratio']?.toDouble(),
      riskFactorScore: json['risk_factor_score']?.toDouble(),
      scoreLabel: json['score_label'] ?? 'NOT_CALCULATED',
    );
  }
}


// ============================================================================
// APPEND THIS BLOCK TO: frontend/lib/models/analytics_models.dart
// Place it anywhere after the FinancialScoreResponse class (e.g. right
// after the "Financial Score Models" section, before "Forecast Models").
// ============================================================================

// ============================================================================
// Score Trend Models (Phase 8 — Score History)
// ============================================================================

class ScoreTrendPoint {
  final DateTime scoreMonth;
  final double avgScore;
  final double peakScore;
  final double lowScore;

  ScoreTrendPoint({
    required this.scoreMonth,
    required this.avgScore,
    required this.peakScore,
    required this.lowScore,
  });

  factory ScoreTrendPoint.fromJson(Map<String, dynamic> json) {
    return ScoreTrendPoint(
      scoreMonth: json['score_month'] != null
          ? DateTime.parse(json['score_month'])
          : DateTime.now(),
      avgScore: (json['avg_score'] ?? 0).toDouble(),
      peakScore: (json['peak_score'] ?? 0).toDouble(),
      lowScore: (json['low_score'] ?? 0).toDouble(),
    );
  }

  String get monthLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[scoreMonth.month - 1];
  }
}

class ScoreTrendResponse {
  final List<ScoreTrendPoint> trend;
  final double currentScore;
  final String currentLabel;
  final double? improvement;

  ScoreTrendResponse({
    required this.trend,
    required this.currentScore,
    required this.currentLabel,
    this.improvement,
  });

  factory ScoreTrendResponse.fromJson(Map<String, dynamic> json) {
    final trendList = json['trend'] as List? ?? [];
    return ScoreTrendResponse(
      trend: trendList.map((t) => ScoreTrendPoint.fromJson(t)).toList(),
      currentScore: (json['current_score'] ?? 0).toDouble(),
      currentLabel: json['current_label'] ?? 'NOT_CALCULATED',
      improvement: json['improvement']?.toDouble(),
    );
  }
}
// ============================================================================
// Forecast Models
// ============================================================================

class CurrentMonthForecast {
  final DateTime month;
  final double spentSoFar;
  final double budgetLimit;
  final double projectedTotal;
  final double remainingBudget;
  final int daysRemaining;
  final double dailyAllowance;
  final double currentVelocity;
  final double variancePct;
  final int? daysToBreach;
  final String status;
  final String message;

  CurrentMonthForecast({
    required this.month,
    required this.spentSoFar,
    required this.budgetLimit,
    required this.projectedTotal,
    required this.remainingBudget,
    required this.daysRemaining,
    required this.dailyAllowance,
    required this.currentVelocity,
    required this.variancePct,
    this.daysToBreach,
    required this.status,
    required this.message,
  });

  factory CurrentMonthForecast.fromJson(Map<String, dynamic> json) {
    return CurrentMonthForecast(
      month: json['month'] != null ? DateTime.parse(json['month']) : DateTime.now(),
      spentSoFar: (json['spent_so_far'] ?? 0).toDouble(),
      budgetLimit: (json['budget_limit'] ?? 0).toDouble(),
      projectedTotal: (json['projected_total'] ?? 0).toDouble(),
      remainingBudget: (json['remaining_budget'] ?? 0).toDouble(),
      daysRemaining: json['days_remaining'] ?? 0,
      dailyAllowance: (json['daily_allowance'] ?? 0).toDouble(),
      currentVelocity: (json['current_velocity'] ?? 0).toDouble(),
      variancePct: (json['variance_pct'] ?? 0).toDouble(),
      daysToBreach: json['days_to_breach'],
      status: json['status'] ?? 'ON_TRACK',
      message: json['message'] ?? '',
    );
  }
}

// ============================================================================
// Insights Models
// ============================================================================

class InsightsResponse {
  final String primaryInsight;
  final List<String> subscriptionInsights;
  final String budgetInsight;
  final String savingsInsight;
  final DateTime generatedAt;

  InsightsResponse({
    required this.primaryInsight,
    required this.subscriptionInsights,
    required this.budgetInsight,
    required this.savingsInsight,
    required this.generatedAt,
  });

  factory InsightsResponse.fromJson(Map<String, dynamic> json) {
    return InsightsResponse(
      primaryInsight: json['primary_insight'] ?? '',
      subscriptionInsights: json['subscription_insights'] != null
          ? List<String>.from(json['subscription_insights'])
          : [],
      budgetInsight: json['budget_insight'] ?? '',
      savingsInsight: json['savings_insight'] ?? '',
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'])
          : DateTime.now(),
    );
  }
}

// ============================================================================
// Alert Summary Models
// ============================================================================

class AlertSummaryResponse {
  final int totalAlerts;
  final int unreadAlerts;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final Map<String, int> byType;

  AlertSummaryResponse({
    required this.totalAlerts,
    required this.unreadAlerts,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.byType,
  });

  factory AlertSummaryResponse.fromJson(Map<String, dynamic> json) {
    return AlertSummaryResponse(
      totalAlerts: json['total_alerts'] ?? 0,
      unreadAlerts: json['unread_alerts'] ?? 0,
      criticalCount: json['critical_count'] ?? 0,
      highCount: json['high_count'] ?? 0,
      mediumCount: json['medium_count'] ?? 0,
      lowCount: json['low_count'] ?? 0,
      byType: json['by_type'] != null
          ? Map<String, int>.from(json['by_type'])
          : {},
    );
  }
}

// ============================================================================
// Category Analytics Models
// ============================================================================

class CategorySpendResponse {
  final String categoryName;
  final int categoryId;
  final String? iconCode;
  final String? colorHex;
  final double totalAmount;
  final int paymentCount;
  final double pctOfTotal;
  final DateTime month;

  CategorySpendResponse({
    required this.categoryName,
    required this.categoryId,
    this.iconCode,
    this.colorHex,
    required this.totalAmount,
    required this.paymentCount,
    required this.pctOfTotal,
    required this.month,
  });

  factory CategorySpendResponse.fromJson(Map<String, dynamic> json) {
    return CategorySpendResponse(
      categoryName: json['category_name'] ?? '',
      categoryId: json['category_id'] ?? 0,
      iconCode: json['icon_code'],
      colorHex: json['color_hex'],
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      paymentCount: json['payment_count'] ?? 0,
      pctOfTotal: (json['pct_of_total'] ?? 0).toDouble(),
      month: json['month'] != null ? DateTime.parse(json['month']) : DateTime.now(),
    );
  }

  Color get color {
    if (colorHex != null && colorHex!.isNotEmpty) {
      try {
        return Color(int.parse('FF$colorHex', radix: 16));
      } catch (_) {}
    }
    return _getDefaultColor(categoryName);
  }

  Color _getDefaultColor(String name) {
    final colors = {
      'Streaming': const Color(0xFFE50914),
      'Music': const Color(0xFF1DB954),
      'SaaS Tools': const Color(0xFF0078D4),
      'Gaming': const Color(0xFF7B2FBE),
      'Cloud Storage': const Color(0xFFF4900C),
      'Security VPN': const Color(0xFF22C55E),
      'Utilities': const Color(0xFFEAB308),
      'News Reading': const Color(0xFF6B7280),
      'AI Tools': const Color(0xFF8B5CF6),
      'Fitness Health': const Color(0xFFEF4444),
    };
    return colors[name] ?? const Color(0xFF4A9EFF);
  }
}

class MonthlyCategorySummary {
  final DateTime month;
  final double totalSpend;
  final String topCategory;
  final double topCategoryAmount;
  final List<CategorySpendResponse> categories;

  MonthlyCategorySummary({
    required this.month,
    required this.totalSpend,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.categories,
  });

  factory MonthlyCategorySummary.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'] as List? ?? [];
    return MonthlyCategorySummary(
      month: json['month'] != null ? DateTime.parse(json['month']) : DateTime.now(),
      totalSpend: (json['total_spend'] ?? 0).toDouble(),
      topCategory: json['top_category'] ?? '',
      topCategoryAmount: (json['top_category_amount'] ?? 0).toDouble(),
      categories: categories
          .map((c) => CategorySpendResponse.fromJson(c))
          .toList(),
    );
  }

  String get monthLabel {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }
}

class SpendingPatternResponse {
  final int patternId;
  final String categoryName;
  final DateTime patternMonth;
  final double totalSpent;
  final int txnCount;
  final double avgTxnAmount;
  final double? momChangePct;

  SpendingPatternResponse({
    required this.patternId,
    required this.categoryName,
    required this.patternMonth,
    required this.totalSpent,
    required this.txnCount,
    required this.avgTxnAmount,
    this.momChangePct,
  });

  factory SpendingPatternResponse.fromJson(Map<String, dynamic> json) {
    return SpendingPatternResponse(
      patternId: json['pattern_id'] ?? 0,
      categoryName: json['category_name'] ?? '',
      patternMonth: json['pattern_month'] != null
          ? DateTime.parse(json['pattern_month'])
          : DateTime.now(),
      totalSpent: (json['total_spent'] ?? 0).toDouble(),
      txnCount: json['txn_count'] ?? 0,
      avgTxnAmount: (json['avg_txn_amount'] ?? 0).toDouble(),
      momChangePct: json['mom_change_pct']?.toDouble(),
    );
  }
}

// ============================================================================
// NEW: Day of Week Spending Model
// ============================================================================

class DayOfWeekSpend {
  final String dayOfWeek;
  final double totalAmount;
  final int transactionCount;

  DayOfWeekSpend({
    required this.dayOfWeek,
    required this.totalAmount,
    required this.transactionCount,
  });

  factory DayOfWeekSpend.fromJson(Map<String, dynamic> json) {
    return DayOfWeekSpend(
      dayOfWeek: json['day_of_week'] ?? '',
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      transactionCount: json['transaction_count'] ?? 0,
    );
  }
}