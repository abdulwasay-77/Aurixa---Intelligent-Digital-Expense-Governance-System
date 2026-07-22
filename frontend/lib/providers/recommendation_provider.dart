/// Recommendation State Management — AI-powered subscription suggestions
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recommendation_models.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';

// ============================================================================
// State Definition
// ============================================================================

class RecommendationState {
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final List<RecommendationResponse> recommendations;

  /// Grand total — ALL recommendations regardless of active filter.
  /// Never overwritten when a type filter is applied.
  final int totalCount;

  /// Count for the currently active filter.
  /// Equals totalCount when no filter is active (selectedType == null).
  final int filteredCount;

  final int actionedCount;
  final double totalPotentialSavings;
  final RecommendationSummaryResponse? summary;
  final SavingsImpactResponse? savingsImpact;
  final int page;
  final int pageSize;
  final String? selectedType;
  final bool isGenerating;

  const RecommendationState({
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.recommendations = const [],
    this.totalCount = 0,
    this.filteredCount = 0,
    this.actionedCount = 0,
    this.totalPotentialSavings = 0,
    this.summary,
    this.savingsImpact,
    this.page = 1,
    this.pageSize = 20,
    this.selectedType,
    this.isGenerating = false,
  });

  RecommendationState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    List<RecommendationResponse>? recommendations,
    int? totalCount,
    int? filteredCount,
    int? actionedCount,
    double? totalPotentialSavings,
    RecommendationSummaryResponse? summary,
    SavingsImpactResponse? savingsImpact,
    int? page,
    int? pageSize,
    String? selectedType,
    bool? isGenerating,
    // Sentinel to allow explicitly clearing selectedType to null
    bool clearSelectedType = false,
  }) {
    return RecommendationState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      recommendations: recommendations ?? this.recommendations,
      totalCount: totalCount ?? this.totalCount,
      filteredCount: filteredCount ?? this.filteredCount,
      actionedCount: actionedCount ?? this.actionedCount,
      totalPotentialSavings: totalPotentialSavings ?? this.totalPotentialSavings,
      summary: summary ?? this.summary,
      savingsImpact: savingsImpact ?? this.savingsImpact,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      selectedType: clearSelectedType ? null : (selectedType ?? this.selectedType),
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

class RecommendationNotifier extends AsyncNotifier<RecommendationState> {
  @override
  Future<RecommendationState> build() async {
    return await _loadRecommendationData();
  }

  Future<RecommendationState> _loadRecommendationData() async {
    try {
      final results = await Future.wait([
        _fetchRecommendations(),
        _fetchSummary(),
        _fetchSavingsImpact(),
      ]);

      final recList = results[0] as RecommendationListResponse;
      final summary = results[1] as RecommendationSummaryResponse;
      final savingsImpact = results[2] as SavingsImpactResponse;

      // Use summary.totalRecommendations as the authoritative grand total
      // so that totalCount is never corrupted by a filter operation.
      final grandTotal = summary.totalRecommendations > 0
          ? summary.totalRecommendations
          : recList.totalCount;

      return RecommendationState(
        isLoading: false,
        hasError: false,
        recommendations: recList.recommendations,
        totalCount: grandTotal,        // ← grand total, never touched by filters
        filteredCount: recList.totalCount, // ← same as grand total when no filter
        actionedCount: recList.actionedCount,
        totalPotentialSavings: recList.totalPotentialSavings,
        summary: summary,
        savingsImpact: savingsImpact,
        page: recList.page,
        pageSize: recList.pageSize,
        selectedType: null,            // ← always reset on full refresh
        isGenerating: false,
      );
    } catch (e) {
      debugPrint('Recommendation loading error: $e');
      return const RecommendationState(
        isLoading: false,
        hasError: true,
        errorMessage: 'Failed to load recommendations',
      );
    }
  }

  Future<RecommendationListResponse> _fetchRecommendations({
    String? type,
    int page = 1,
    int pageSize = 20,
    bool pendingOnly = false,
  }) async {
    try {
      String url = '${AppConstants.apiRecommendations}?limit=$pageSize&offset=${(page - 1) * pageSize}';
      if (type != null && type.isNotEmpty) {
        url += '&rec_type=$type';
      }
      if (pendingOnly) {
        url += '&pending_only=true';
      }

      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        return RecommendationListResponse.fromJson(response.data);
      }
      return RecommendationListResponse(
        recommendations: [],
        totalCount: 0,
        actionedCount: 0,
        totalPotentialSavings: 0,
        page: 1,
        pageSize: 20,
      );
    } catch (e) {
      debugPrint('Recommendations fetch error: $e');
      return RecommendationListResponse(
        recommendations: [],
        totalCount: 0,
        actionedCount: 0,
        totalPotentialSavings: 0,
        page: 1,
        pageSize: 20,
      );
    }
  }

  Future<RecommendationSummaryResponse> _fetchSummary() async {
    try {
      final response = await ApiService.get('${AppConstants.apiRecommendations}/summary');
      if (response.statusCode == 200) {
        return RecommendationSummaryResponse.fromJson(response.data);
      }
      return RecommendationSummaryResponse(
        totalRecommendations: 0,
        pendingRecommendations: 0,
        actionedRecommendations: 0,
        totalPotentialSavings: 0,
        byType: {},
        topSavingRecommendation: null,
      );
    } catch (e) {
      debugPrint('Recommendation summary fetch error: $e');
      return RecommendationSummaryResponse(
        totalRecommendations: 0,
        pendingRecommendations: 0,
        actionedRecommendations: 0,
        totalPotentialSavings: 0,
        byType: {},
        topSavingRecommendation: null,
      );
    }
  }

  Future<SavingsImpactResponse> _fetchSavingsImpact() async {
    try {
      final response = await ApiService.get('${AppConstants.apiRecommendations}/savings/impact');
      if (response.statusCode == 200) {
        return SavingsImpactResponse.fromJson(response.data);
      }
      return SavingsImpactResponse(
        currentMonthlySpend: 0,
        projectedMonthlySpend: 0,
        monthlySavings: 0,
        yearlySavings: 0,
        recommendationsApplied: 0,
        recommendationsPending: 0,
      );
    } catch (e) {
      debugPrint('Savings impact fetch error: $e');
      return SavingsImpactResponse(
        currentMonthlySpend: 0,
        projectedMonthlySpend: 0,
        monthlySavings: 0,
        yearlySavings: 0,
        recommendationsApplied: 0,
        recommendationsPending: 0,
      );
    }
  }

  // ==========================================================================
  // CRUD Operations
  // ==========================================================================

  Future<bool> actionRecommendation(int recId, String actionTaken, {String? notes}) async {
    try {
      final request = ActionRecommendationRequest(
        actionTaken: actionTaken,
        notes: notes,
      );
      final response = await ApiService.put(
        '${AppConstants.apiRecommendations}/$recId/action',
        data: request.toJson(),
      );
      if (response.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Action recommendation error: $e');
      return false;
    }
  }

  Future<bool> generateRecommendations() async {
    try {
      // Set generating state
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(currentState.copyWith(isGenerating: true));
      }

      final response = await ApiService.post('${AppConstants.apiRecommendations}/generate');
      if (response.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Generate recommendations error: $e');
      return false;
    } finally {
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(currentState.copyWith(isGenerating: false));
      }
    }
  }

  /// Filter the list by [type]. Pass null to clear the filter (show all).
  ///
  /// KEY FIX: Only [filteredCount] and [recommendations] are updated here.
  /// [totalCount] (the grand total) is NEVER touched — it stays authoritative
  /// so that _buildEmptyState always knows whether recommendations exist at all.
  Future<void> filterByType(String? type) async {
    final currentState = state.value;
    if (currentState == null) return;

    try {
      final recList = await _fetchRecommendations(
        type: type,
        page: 1,
        pageSize: currentState.pageSize,
      );

      state = AsyncValue.data(currentState.copyWith(
        recommendations: recList.recommendations,
        // ✅ Only filteredCount changes — totalCount stays untouched
        filteredCount: recList.totalCount,
        actionedCount: recList.actionedCount,
        totalPotentialSavings: recList.totalPotentialSavings,
        page: recList.page,
        selectedType: type,
        clearSelectedType: type == null,
      ));
    } catch (e) {
      debugPrint('Filter error: $e');
    }
  }

  Future<void> goToPage(int page) async {
    final currentState = state.value;
    if (currentState == null) return;

    try {
      final recList = await _fetchRecommendations(
        type: currentState.selectedType,
        page: page,
        pageSize: currentState.pageSize,
      );

      state = AsyncValue.data(currentState.copyWith(
        recommendations: recList.recommendations,
        filteredCount: recList.totalCount,
        actionedCount: recList.actionedCount,
        totalPotentialSavings: recList.totalPotentialSavings,
        page: recList.page,
      ));
    } catch (e) {
      debugPrint('Page navigation error: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadRecommendationData());
  }
}

// ============================================================================
// Provider
// ============================================================================

final recommendationProvider =
    AsyncNotifierProvider<RecommendationNotifier, RecommendationState>(
  RecommendationNotifier.new,
);