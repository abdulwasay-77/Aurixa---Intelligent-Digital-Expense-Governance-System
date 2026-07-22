/// Analytics State Management
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analytics_models.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';

// ============================================================================
// State Definition
// ============================================================================

class AnalyticsState {
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final List<CategorySpendResponse> currentMonthCategories;
  final List<MonthlyCategorySummary> monthlySummary;
  final List<SpendingPatternResponse> patterns;
  final List<DayOfWeekSpend> dayOfWeekData;  // NEW
  final DateTime selectedMonth;

  const AnalyticsState({
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.currentMonthCategories = const [],
    this.monthlySummary = const [],
    this.patterns = const [],
    this.dayOfWeekData = const [],  // NEW
    required this.selectedMonth,
  });

  AnalyticsState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    List<CategorySpendResponse>? currentMonthCategories,
    List<MonthlyCategorySummary>? monthlySummary,
    List<SpendingPatternResponse>? patterns,
    List<DayOfWeekSpend>? dayOfWeekData,  // NEW
    DateTime? selectedMonth,
  }) {
    return AnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      currentMonthCategories: currentMonthCategories ?? this.currentMonthCategories,
      monthlySummary: monthlySummary ?? this.monthlySummary,
      patterns: patterns ?? this.patterns,
      dayOfWeekData: dayOfWeekData ?? this.dayOfWeekData,  // NEW
      selectedMonth: selectedMonth ?? this.selectedMonth,
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  @override
  Future<AnalyticsState> build() async {
    return await _loadAnalyticsData();
  }

  Future<AnalyticsState> _loadAnalyticsData() async {
    try {
      final now = DateTime.now();
      final selectedMonth = DateTime(now.year, now.month, 1);

      final results = await Future.wait([
        _fetchCurrentMonthCategories(selectedMonth),
        _fetchMonthlySummary(),
        _fetchPatterns(selectedMonth),
        _fetchDayOfWeekData(selectedMonth),  // NEW
      ]);

      return AnalyticsState(
        isLoading: false,
        hasError: false,
        currentMonthCategories: results[0] as List<CategorySpendResponse>,
        monthlySummary: results[1] as List<MonthlyCategorySummary>,
        patterns: results[2] as List<SpendingPatternResponse>,
        dayOfWeekData: results[3] as List<DayOfWeekSpend>,  // NEW
        selectedMonth: selectedMonth,
      );
    } catch (e) {
      debugPrint('Analytics loading error: $e');
      final now = DateTime.now();
      return AnalyticsState(
        isLoading: false,
        hasError: true,
        errorMessage: 'Failed to load analytics data',
        selectedMonth: DateTime(now.year, now.month, 1),
      );
    }
  }

  Future<List<CategorySpendResponse>> _fetchCurrentMonthCategories(DateTime month) async {
    try {
      final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final response = await ApiService.get(
        '${AppConstants.apiCategories}?month=$monthStr',
      );
      if (response.statusCode == 200) {
        final data = response.data as List? ?? [];
        return data
            .map((json) => CategorySpendResponse.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Current month categories fetch error: $e');
      return [];
    }
  }

  Future<List<MonthlyCategorySummary>> _fetchMonthlySummary() async {
    try {
      final response = await ApiService.get(
        AppConstants.apiMonthlySummary,
      );
      if (response.statusCode == 200) {
        final data = response.data as List? ?? [];
        return data
            .map((json) => MonthlyCategorySummary.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Monthly summary fetch error: $e');
      return [];
    }
  }

  Future<List<SpendingPatternResponse>> _fetchPatterns(DateTime month) async {
    try {
      final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final response = await ApiService.get(
        '${AppConstants.apiPatterns}?month=$monthStr',
      );
      if (response.statusCode == 200) {
        final data = response.data as List? ?? [];
        return data
            .map((json) => SpendingPatternResponse.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Patterns fetch error: $e');
      return [];
    }
  }

  // ================================================================
  // NEW: Fetch Day of Week Data from TRANSACTIONS table
  // ================================================================
  Future<List<DayOfWeekSpend>> _fetchDayOfWeekData(DateTime month) async {
    try {
      final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final response = await ApiService.get(
        '${AppConstants.apiDayOfWeek}?month=$monthStr',
      );
      if (response.statusCode == 200) {
        final data = response.data as List? ?? [];
        return data
            .map((json) => DayOfWeekSpend.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Day of week fetch error: $e');
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadAnalyticsData());
  }

  Future<void> changeMonth(DateTime newMonth) async {
    final month = DateTime(newMonth.year, newMonth.month, 1);
    try {
      final categories = await _fetchCurrentMonthCategories(month);
      final patterns = await _fetchPatterns(month);
      final dayOfWeek = await _fetchDayOfWeekData(month);  // NEW
      
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(currentState.copyWith(
          selectedMonth: month,
          currentMonthCategories: categories,
          patterns: patterns,
          dayOfWeekData: dayOfWeek,  // NEW
        ));
      }
    } catch (e) {
      debugPrint('Month change error: $e');
    }
  }
}

// ============================================================================
// Provider
// ============================================================================

final analyticsProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(
  AnalyticsNotifier.new,
);