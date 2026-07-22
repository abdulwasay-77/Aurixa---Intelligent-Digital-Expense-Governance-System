/// Alert State Management — RiskRadar
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert_models.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';

// ============================================================================
// State Definition
// ============================================================================

class AlertState {
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final List<AlertResponse> alerts;
  final int totalCount;
  final int unreadCount;
  final AlertSummaryResponse? summary;
  final int page;
  final int pageSize;
  final String? selectedSeverity;
  final bool isAnomalyDetecting;

  const AlertState({
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.alerts = const [],
    this.totalCount = 0,
    this.unreadCount = 0,
    this.summary,
    this.page = 1,
    this.pageSize = 20,
    this.selectedSeverity,
    this.isAnomalyDetecting = false,
  });

  AlertState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    List<AlertResponse>? alerts,
    int? totalCount,
    int? unreadCount,
    AlertSummaryResponse? summary,
    int? page,
    int? pageSize,
    String? selectedSeverity,
    bool? isAnomalyDetecting,
  }) {
    return AlertState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      alerts: alerts ?? this.alerts,
      totalCount: totalCount ?? this.totalCount,
      unreadCount: unreadCount ?? this.unreadCount,
      summary: summary ?? this.summary,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      selectedSeverity: selectedSeverity ?? this.selectedSeverity,
      isAnomalyDetecting: isAnomalyDetecting ?? this.isAnomalyDetecting,
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

class AlertNotifier extends AsyncNotifier<AlertState> {
  @override
  Future<AlertState> build() async {
    return await _loadAlertData();
  }

  Future<AlertState> _loadAlertData() async {
    try {
      final results = await Future.wait([
        _fetchAlerts(),
        _fetchSummary(),
      ]);

      final alertList = results[0] as AlertListResponse;
      final summary = results[1] as AlertSummaryResponse;

      return AlertState(
        isLoading: false,
        hasError: false,
        alerts: alertList.alerts,
        totalCount: alertList.totalCount,
        unreadCount: alertList.unreadCount,
        summary: summary,
        page: alertList.page,
        pageSize: alertList.pageSize,
        selectedSeverity: null,
      );
    } catch (e) {
      debugPrint('Alert loading error: $e');
      return const AlertState(
        isLoading: false,
        hasError: true,
        errorMessage: 'Failed to load alerts',
      );
    }
  }

  Future<AlertListResponse> _fetchAlerts({
    String? severity,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      String url = '${AppConstants.apiAlerts}?limit=$pageSize&offset=${(page - 1) * pageSize}';
      if (severity != null && severity.isNotEmpty) {
        url += '&severity=$severity';
      }

      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        return AlertListResponse.fromJson(response.data);
      }
      return AlertListResponse(
        alerts: [],
        totalCount: 0,
        unreadCount: 0,
        page: 1,
        pageSize: 20,
      );
    } catch (e) {
      debugPrint('Alerts fetch error: $e');
      return AlertListResponse(
        alerts: [],
        totalCount: 0,
        unreadCount: 0,
        page: 1,
        pageSize: 20,
      );
    }
  }

  Future<AlertSummaryResponse> _fetchSummary() async {
    try {
      final response = await ApiService.get(AppConstants.apiAlertsSummary);
      if (response.statusCode == 200) {
        return AlertSummaryResponse.fromJson(response.data);
      }
      return AlertSummaryResponse(
        totalAlerts: 0,
        unreadAlerts: 0,
        criticalCount: 0,
        highCount: 0,
        mediumCount: 0,
        lowCount: 0,
        bySeverity: [],
        byType: {},
      );
    } catch (e) {
      debugPrint('Alert summary fetch error: $e');
      return AlertSummaryResponse(
        totalAlerts: 0,
        unreadAlerts: 0,
        criticalCount: 0,
        highCount: 0,
        mediumCount: 0,
        lowCount: 0,
        bySeverity: [],
        byType: {},
      );
    }
  }

  // ==========================================================================
  // CRUD Operations
  // ==========================================================================

  Future<bool> markAlertRead(int alertId) async {
    try {
      final response = await ApiService.put(
        '${AppConstants.apiAlerts}/$alertId/read',
      );
      if (response.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Mark alert read error: $e');
      return false;
    }
  }

  Future<bool> markAllAlertsRead() async {
    try {
      final response = await ApiService.put(
        '${AppConstants.apiAlerts}/mark-all-read',
      );
      if (response.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Mark all alerts read error: $e');
      return false;
    }
  }

  Future<AnomalyDetectionResponse?> detectAnomalies() async {
    try {
      final loadingState = state.value;
      if (loadingState != null) {
        state = AsyncValue.data(loadingState.copyWith(isAnomalyDetecting: true));
      }

      final response = await ApiService.post(
        '${AppConstants.apiAlerts}/detect-anomalies',
      );
      if (response.statusCode == 200) {
        final result = AnomalyDetectionResponse.fromJson(response.data);
        await refresh();
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('Anomaly detection error: $e');
      return null;
    } finally {
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(currentState.copyWith(isAnomalyDetecting: false));
      }
    }
  }

  Future<void> filterBySeverity(String? severity) async {
    final currentState = state.value;
    if (currentState == null) return;

    try {
      final alertList = await _fetchAlerts(
        severity: severity,
        page: 1,
        pageSize: currentState.pageSize,
      );

      state = AsyncValue.data(currentState.copyWith(
        alerts: alertList.alerts,
        totalCount: alertList.totalCount,
        unreadCount: alertList.unreadCount,
        page: alertList.page,
        selectedSeverity: severity,
      ));
    } catch (e) {
      debugPrint('Filter error: $e');
    }
  }

  Future<void> goToPage(int page) async {
    final currentState = state.value;
    if (currentState == null) return;

    try {
      final alertList = await _fetchAlerts(
        severity: currentState.selectedSeverity,
        page: page,
        pageSize: currentState.pageSize,
      );

      state = AsyncValue.data(currentState.copyWith(
        alerts: alertList.alerts,
        totalCount: alertList.totalCount,
        unreadCount: alertList.unreadCount,
        page: alertList.page,
      ));
    } catch (e) {
      debugPrint('Page navigation error: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadAlertData());
  }
}

// ============================================================================
// Provider
// ============================================================================

final alertProvider =
    AsyncNotifierProvider<AlertNotifier, AlertState>(
  AlertNotifier.new,
);