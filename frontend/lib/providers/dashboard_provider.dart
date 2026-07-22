/// Dashboard State Management
/// PERF FIX: Migrated from StateNotifierProvider to AsyncNotifierProvider.
/// StateNotifier triggered full reload whenever the provider was re-read.
/// AsyncNotifier caches state and only reloads when explicitly called.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analytics_models.dart';
import '../models/subscription_models.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';

// ============================================================================
// Dashboard State
// ============================================================================

class DashboardState {
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final FinancialScoreResponse? score;
  final CurrentMonthForecast? forecast;
  final InsightsResponse? insights;
  final AlertSummaryResponse? alertSummary;
  final List<SubscriptionResponse> upcomingBilling;
  final int totalMonthlySpend;

  const DashboardState({
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.score,
    this.forecast,
    this.insights,
    this.alertSummary,
    this.upcomingBilling = const [],
    this.totalMonthlySpend = 0,
  });

  DashboardState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    FinancialScoreResponse? score,
    CurrentMonthForecast? forecast,
    InsightsResponse? insights,
    AlertSummaryResponse? alertSummary,
    List<SubscriptionResponse>? upcomingBilling,
    int? totalMonthlySpend,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      score: score ?? this.score,
      forecast: forecast ?? this.forecast,
      insights: insights ?? this.insights,
      alertSummary: alertSummary ?? this.alertSummary,
      upcomingBilling: upcomingBilling ?? this.upcomingBilling,
      totalMonthlySpend: totalMonthlySpend ?? this.totalMonthlySpend,
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() async {
    // Called once when first accessed. Result is cached by Riverpod.
    // Will NOT re-run unless invalidate() or refresh() is called explicitly.
    return await _loadDashboardData();
  }

  Future<DashboardState> _loadDashboardData() async {
    try {
      // All 5 API calls fire in parallel — unchanged from before
      final results = await Future.wait([
        _fetchScore(),
        _fetchForecast(),
        _fetchInsights(),
        _fetchAlertSummary(),
        _fetchSubscriptions(),
      ]);

      final subs = results[4] as List<SubscriptionResponse>;

      return DashboardState(
        isLoading: false,
        hasError: false,
        score: results[0] as FinancialScoreResponse?,
        forecast: results[1] as CurrentMonthForecast?,
        insights: results[2] as InsightsResponse?,
        alertSummary: results[3] as AlertSummaryResponse?,
        upcomingBilling: subs,
        totalMonthlySpend: _calculateTotalSpend(subs),
      );
    } catch (e) {
      debugPrint('Dashboard loading error: $e');
      return const DashboardState(
        isLoading: false,
        hasError: true,
        errorMessage: 'Failed to load dashboard data',
        upcomingBilling: [],
      );
    }
  }

  /// Call this to manually trigger a fresh reload (e.g. pull-to-refresh).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadDashboardData());
  }

  // ── Private fetch helpers ─────────────────────────────────────────────────

  Future<FinancialScoreResponse?> _fetchScore() async {
    try {
      final response = await ApiService.get(AppConstants.apiScore);
      if (response.statusCode == 200) {
        return FinancialScoreResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Score fetch error: $e');
      return null;
    }
  }

  Future<CurrentMonthForecast?> _fetchForecast() async {
    try {
      final response = await ApiService.get(AppConstants.apiForecastCurrent);
      if (response.statusCode == 200) {
        return CurrentMonthForecast.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Forecast fetch error: $e');
      return null;
    }
  }

  Future<InsightsResponse?> _fetchInsights() async {
    try {
      final response = await ApiService.get(AppConstants.apiInsights);
      if (response.statusCode == 200) {
        return InsightsResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Insights fetch error: $e');
      return null;
    }
  }

  Future<AlertSummaryResponse?> _fetchAlertSummary() async {
    try {
      final response = await ApiService.get(AppConstants.apiAlertsSummary);
      if (response.statusCode == 200) {
        return AlertSummaryResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Alert summary fetch error: $e');
      return null;
    }
  }

  Future<List<SubscriptionResponse>> _fetchSubscriptions() async {
    try {
      final response = await ApiService.get(AppConstants.apiSubscriptions);
      if (response.statusCode == 200) {
        final data = response.data;
        final subscriptions = data['subscriptions'] as List? ?? [];
        return subscriptions
            .map((json) => SubscriptionResponse.fromJson(json))
            .where((s) => s.status == 'ACTIVE')
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Subscriptions fetch error: $e');
      return [];
    }
  }

  int _calculateTotalSpend(List<SubscriptionResponse> subscriptions) {
    final total = subscriptions.fold<double>(0, (sum, sub) {
      double monthlyAmount = sub.billingAmount;
      if (sub.billingCycle == 'YEARLY') monthlyAmount = sub.billingAmount / 12;
      if (sub.billingCycle == 'QUARTERLY') {
        monthlyAmount = sub.billingAmount / 3;
      }
      if (sub.billingCycle == 'WEEKLY') {
        monthlyAmount = sub.billingAmount * 4.33;
      }
      return sum + monthlyAmount;
    });
    return total.round();
  }
}

// ============================================================================
// Provider
// ============================================================================

/// PERF FIX: AsyncNotifierProvider caches the result after first build().
/// Old StateNotifierProvider with constructor-triggered load could re-run
/// whenever Riverpod recreated the notifier due to widget tree changes.
final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);