/// Recommendation Models — AI-powered subscription recommendations
library;

// ============================================================================
// Recommendation Response Model
// ============================================================================
import 'package:flutter/material.dart';

class RecommendationResponse {
  final int recId;
  final int userId;
  final String recType;
  final int? subId;
  final String? subName;
  final String? vendorName;
  final String? categoryName;
  final String title;
  final String reasoning;
  final double? potentialSaving;
  final String? savingCurrencyCode;
  final String? savingCurrencySymbol;
  final double? confidenceScore;
  final String source;
  final bool isActioned;
  final DateTime generatedAt;

  RecommendationResponse({
    required this.recId,
    required this.userId,
    required this.recType,
    this.subId,
    this.subName,
    this.vendorName,
    this.categoryName,
    required this.title,
    required this.reasoning,
    this.potentialSaving,
    this.savingCurrencyCode,
    this.savingCurrencySymbol,
    this.confidenceScore,
    required this.source,
    required this.isActioned,
    required this.generatedAt,
  });

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) {
    return RecommendationResponse(
      recId: json['rec_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      recType: json['rec_type'] ?? '',
      subId: json['sub_id'],
      subName: json['sub_name'],
      vendorName: json['vendor_name'],
      categoryName: json['category_name'],
      title: json['title'] ?? '',
      reasoning: json['reasoning'] ?? '',
      potentialSaving: json['potential_saving']?.toDouble(),
      savingCurrencyCode: json['saving_currency_code'],
      savingCurrencySymbol: json['saving_currency_symbol'],
      confidenceScore: json['confidence_score']?.toDouble(),
      source: json['source'] ?? 'PROCEDURE',
      isActioned: json['is_actioned'] ?? false,
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'])
          : DateTime.now(),
    );
  }

  String get recTypeLabel {
    switch (recType) {
      case 'CANCEL': return 'Cancel';
      case 'DOWNGRADE': return 'Downgrade';
      case 'YEARLY_PLAN': return 'Yearly Plan';
      case 'CONSOLIDATE': return 'Consolidate';
      case 'ALTERNATIVE': return 'Alternative';
      default: return recType;
    }
  }

  String get recTypeIcon {
    switch (recType) {
      case 'CANCEL': return '❌';
      case 'DOWNGRADE': return '⬇️';
      case 'YEARLY_PLAN': return '📅';
      case 'CONSOLIDATE': return '🔗';
      case 'ALTERNATIVE': return '🔄';
      default: return '💡';
    }
  }

  Color get recTypeColor {
    switch (recType) {
      case 'CANCEL': return const Color(0xFFFF5757);
      case 'DOWNGRADE': return const Color(0xFFFFB347);
      case 'YEARLY_PLAN': return const Color(0xFF4A9EFF);
      case 'CONSOLIDATE': return const Color(0xFF6C63FF);
      case 'ALTERNATIVE': return const Color(0xFF00C2FF);
      default: return const Color(0xFF8B93A1);
    }
  }

  String get formattedSaving {
    if (potentialSaving == null) return '—';
    final symbol = savingCurrencySymbol ?? '\$';
    return '$symbol${potentialSaving!.toStringAsFixed(2)}';
  }

  String get yearlySaving {
    if (potentialSaving == null) return '—';
    final yearly = potentialSaving! * 12;
    final symbol = savingCurrencySymbol ?? '\$';
    return '$symbol${yearly.toStringAsFixed(0)}';
  }
}

// ============================================================================
// Recommendation List Response
// ============================================================================

class RecommendationListResponse {
  final List<RecommendationResponse> recommendations;
  final int totalCount;
  final int actionedCount;
  final double totalPotentialSavings;
  final int page;
  final int pageSize;

  RecommendationListResponse({
    required this.recommendations,
    required this.totalCount,
    required this.actionedCount,
    required this.totalPotentialSavings,
    required this.page,
    required this.pageSize,
  });

  factory RecommendationListResponse.fromJson(Map<String, dynamic> json) {
    final recommendations = json['recommendations'] as List? ?? [];
    return RecommendationListResponse(
      recommendations: recommendations
          .map((r) => RecommendationResponse.fromJson(r))
          .toList(),
      totalCount: json['total_count'] ?? 0,
      actionedCount: json['actioned_count'] ?? 0,
      totalPotentialSavings: (json['total_potential_savings'] ?? 0).toDouble(),
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 20,
    );
  }
}

// ============================================================================
// Recommendation Summary
// ============================================================================

class RecommendationSummaryResponse {
  final int totalRecommendations;
  final int pendingRecommendations;
  final int actionedRecommendations;
  final double totalPotentialSavings;
  final Map<String, int> byType;
  final RecommendationResponse? topSavingRecommendation;

  RecommendationSummaryResponse({
    required this.totalRecommendations,
    required this.pendingRecommendations,
    required this.actionedRecommendations,
    required this.totalPotentialSavings,
    required this.byType,
    this.topSavingRecommendation,
  });

  factory RecommendationSummaryResponse.fromJson(Map<String, dynamic> json) {
    return RecommendationSummaryResponse(
      totalRecommendations: json['total_recommendations'] ?? 0,
      pendingRecommendations: json['pending_recommendations'] ?? 0,
      actionedRecommendations: json['actioned_recommendations'] ?? 0,
      totalPotentialSavings: (json['total_potential_savings'] ?? 0).toDouble(),
      byType: json['by_type'] != null
          ? Map<String, int>.from(json['by_type'])
          : {},
      topSavingRecommendation: json['top_saving_recommendation'] != null
          ? RecommendationResponse.fromJson(json['top_saving_recommendation'])
          : null,
    );
  }
}

// ============================================================================
// Savings Impact
// ============================================================================

class SavingsImpactResponse {
  final double currentMonthlySpend;
  final double projectedMonthlySpend;
  final double monthlySavings;
  final double yearlySavings;
  final int recommendationsApplied;
  final int recommendationsPending;

  SavingsImpactResponse({
    required this.currentMonthlySpend,
    required this.projectedMonthlySpend,
    required this.monthlySavings,
    required this.yearlySavings,
    required this.recommendationsApplied,
    required this.recommendationsPending,
  });

  factory SavingsImpactResponse.fromJson(Map<String, dynamic> json) {
    return SavingsImpactResponse(
      currentMonthlySpend: (json['current_monthly_spend'] ?? 0).toDouble(),
      projectedMonthlySpend: (json['projected_monthly_spend'] ?? 0).toDouble(),
      monthlySavings: (json['monthly_savings'] ?? 0).toDouble(),
      yearlySavings: (json['yearly_savings'] ?? 0).toDouble(),
      recommendationsApplied: json['recommendations_applied'] ?? 0,
      recommendationsPending: json['recommendations_pending'] ?? 0,
    );
  }
}

// ============================================================================
// Action Request
// ============================================================================

class ActionRecommendationRequest {
  final String actionTaken;
  final String? notes;

  ActionRecommendationRequest({
    required this.actionTaken,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'action_taken': actionTaken,
    'notes': notes,
  };
}

class ActionRecommendationResponse {
  final bool success;
  final String message;
  final int recommendationId;
  final String actionTaken;

  ActionRecommendationResponse({
    required this.success,
    required this.message,
    required this.recommendationId,
    required this.actionTaken,
  });

  factory ActionRecommendationResponse.fromJson(Map<String, dynamic> json) {
    return ActionRecommendationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      recommendationId: json['recommendation_id'] ?? 0,
      actionTaken: json['action_taken'] ?? '',
    );
  }
}