/// Forecast State Management
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analytics_models.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';

// ============================================================================
// State Definition
// ============================================================================

class ForecastState {
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final CurrentMonthForecast? forecast;

  const ForecastState({
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.forecast,
  });

  ForecastState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    CurrentMonthForecast? forecast,
  }) {
    return ForecastState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      forecast: forecast ?? this.forecast,
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

class ForecastNotifier extends AsyncNotifier<ForecastState> {
  @override
  Future<ForecastState> build() async {
    return await _loadForecastData();
  }

  Future<ForecastState> _loadForecastData() async {
    try {
      final forecast = await _fetchForecast();

      return ForecastState(
        isLoading: false,
        hasError: false,
        forecast: forecast,
      );
    } catch (e) {
      debugPrint('Forecast loading error: $e');
      return const ForecastState(
        isLoading: false,
        hasError: true,
        errorMessage: 'Failed to load forecast data',
      );
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

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadForecastData());
  }
}

// ============================================================================
// Provider
// ============================================================================

final forecastProvider =
    AsyncNotifierProvider<ForecastNotifier, ForecastState>(
  ForecastNotifier.new,
);