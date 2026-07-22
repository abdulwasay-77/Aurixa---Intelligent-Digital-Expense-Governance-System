/// Score History State Management — Phase 8
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analytics_models.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';

// ============================================================================
// State Definition
// ============================================================================

class ScoreHistoryState {
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final FinancialScoreResponse? latestScore;
  final ScoreTrendResponse? trend;

  const ScoreHistoryState({
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.latestScore,
    this.trend,
  });

  ScoreHistoryState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    FinancialScoreResponse? latestScore,
    ScoreTrendResponse? trend,
  }) {
    return ScoreHistoryState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      latestScore: latestScore ?? this.latestScore,
      trend: trend ?? this.trend,
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

class ScoreHistoryNotifier extends AsyncNotifier<ScoreHistoryState> {
  @override
  Future<ScoreHistoryState> build() async {
    return await _loadScoreHistoryData();
  }

  Future<ScoreHistoryState> _loadScoreHistoryData() async {
    try {
      final results = await Future.wait([
        _fetchLatestScore(),
        _fetchTrend(),
      ]);

      return ScoreHistoryState(
        isLoading: false,
        hasError: false,
        latestScore: results[0] as FinancialScoreResponse?,
        trend: results[1] as ScoreTrendResponse?,
      );
    } catch (e) {
      debugPrint('Score history loading error: $e');
      return const ScoreHistoryState(
        isLoading: false,
        hasError: true,
        errorMessage: 'Failed to load score history',
      );
    }
  }

  Future<FinancialScoreResponse?> _fetchLatestScore() async {
    try {
      final response = await ApiService.get(AppConstants.apiScore);
      if (response.statusCode == 200) {
        return FinancialScoreResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Latest score fetch error: $e');
      return null;
    }
  }

  Future<ScoreTrendResponse?> _fetchTrend() async {
    try {
      final response = await ApiService.get(AppConstants.apiScoreTrend);
      if (response.statusCode == 200) {
        return ScoreTrendResponse.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Score trend fetch error: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadScoreHistoryData());
  }
}

// ============================================================================
// Provider
// ============================================================================

final scoreHistoryProvider =
    AsyncNotifierProvider<ScoreHistoryNotifier, ScoreHistoryState>(
  ScoreHistoryNotifier.new,
);