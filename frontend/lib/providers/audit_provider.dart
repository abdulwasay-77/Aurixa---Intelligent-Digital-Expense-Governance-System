/// Audit Trail State Management
/// AsyncNotifier following the exact same pattern used by alert_provider.dart,
/// wallet_provider.dart, and every other provider in the project.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_models.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';

// ============================================================================
// State
// ============================================================================

class AuditState {
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final List<AuditLogResponse> logs;
  final int totalCount;
  final AuditSummaryResponse? summary;
  // Pagination
  final int currentOffset;
  final bool hasMorePages;
  // Active filters
  final String? selectedOperation; // INSERT | UPDATE | DELETE | null = All
  final String? selectedTable;     // e.g. SUBSCRIPTIONS | null = All

  static const int _pageSize = 20;

  const AuditState({
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.logs = const [],
    this.totalCount = 0,
    this.summary,
    this.currentOffset = 0,
    this.hasMorePages = false,
    this.selectedOperation,
    this.selectedTable,
  });

  AuditState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    List<AuditLogResponse>? logs,
    int? totalCount,
    AuditSummaryResponse? summary,
    int? currentOffset,
    bool? hasMorePages,
    String? selectedOperation,
    bool clearOperation = false,
    String? selectedTable,
    bool clearTable = false,
  }) {
    return AuditState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      logs: logs ?? this.logs,
      totalCount: totalCount ?? this.totalCount,
      summary: summary ?? this.summary,
      currentOffset: currentOffset ?? this.currentOffset,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      selectedOperation:
          clearOperation ? null : (selectedOperation ?? this.selectedOperation),
      selectedTable:
          clearTable ? null : (selectedTable ?? this.selectedTable),
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

class AuditNotifier extends AsyncNotifier<AuditState> {
  static const int _pageSize = 20;

  @override
  Future<AuditState> build() async {
    return await _loadAll();
  }

  // --------------------------------------------------------------------------
  // Private loaders
  // --------------------------------------------------------------------------

  Future<AuditState> _loadAll({
    String? operation,
    String? tableName,
  }) async {
    try {
      final results = await Future.wait([
        _fetchLogs(operation: operation, tableName: tableName, offset: 0),
        _fetchSummary(),
      ]);

      final logList = results[0] as AuditLogListResponse;
      final summary = results[1] as AuditSummaryResponse;

      return AuditState(
        isLoading: false,
        hasError: false,
        logs: logList.logs,
        totalCount: logList.totalCount,
        summary: summary,
        currentOffset: logList.logs.length,
        hasMorePages: logList.logs.length < logList.totalCount,
        selectedOperation: operation,
        selectedTable: tableName,
      );
    } catch (e) {
      debugPrint('AuditNotifier._loadAll error: $e');
      return const AuditState(
        isLoading: false,
        hasError: true,
        errorMessage: 'Failed to load audit trail',
      );
    }
  }

  Future<AuditLogListResponse> _fetchLogs({
    String? operation,
    String? tableName,
    int offset = 0,
  }) async {
    try {
      String url =
          '${AppConstants.apiAudit}?limit=$_pageSize&offset=$offset';
      if (operation != null && operation.isNotEmpty) {
        url += '&operation=$operation';
      }
      if (tableName != null && tableName.isNotEmpty) {
        url += '&table_name=$tableName';
      }

      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        return AuditLogListResponse.fromJson(
            response.data as Map<String, dynamic>);
      }
      return const AuditLogListResponse(
          logs: [], totalCount: 0, page: 1, pageSize: _pageSize);
    } catch (e) {
      debugPrint('_fetchLogs error: $e');
      return const AuditLogListResponse(
          logs: [], totalCount: 0, page: 1, pageSize: _pageSize);
    }
  }

  Future<AuditSummaryResponse> _fetchSummary() async {
    try {
      final response = await ApiService.get(AppConstants.apiAuditSummary);
      if (response.statusCode == 200) {
        return AuditSummaryResponse.fromJson(
            response.data as Map<String, dynamic>);
      }
      return const AuditSummaryResponse(
        totalEntries: 0,
        insertCount: 0,
        updateCount: 0,
        deleteCount: 0,
        affectedTables: [],
      );
    } catch (e) {
      debugPrint('_fetchSummary error: $e');
      return const AuditSummaryResponse(
        totalEntries: 0,
        insertCount: 0,
        updateCount: 0,
        deleteCount: 0,
        affectedTables: [],
      );
    }
  }

  // --------------------------------------------------------------------------
  // Public actions
  // --------------------------------------------------------------------------

  /// Load more entries and append to the existing list (load-more pagination).
  /// Uses the explicit-typed list literal pattern from Bug 9 to avoid
  /// List<dynamic> inference errors.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMorePages) return;

    try {
      final newLogs = await _fetchLogs(
        operation: current.selectedOperation,
        tableName: current.selectedTable,
        offset: current.currentOffset,
      );

      final List<AuditLogResponse> combined = [
        ...(current.logs),
        ...newLogs.logs,
      ];

      state = AsyncValue.data(current.copyWith(
        logs: combined,
        currentOffset: combined.length,
        hasMorePages: combined.length < newLogs.totalCount,
        totalCount: newLogs.totalCount,
      ));
    } catch (e) {
      debugPrint('loadMore error: $e');
    }
  }

  /// Apply operation filter (INSERT / UPDATE / DELETE / null = All).
  Future<void> filterByOperation(String? operation) async {
    final current = state.value;
    if (current == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadAll(
          operation: operation,
          tableName: current.selectedTable,
        ));
  }

  /// Apply table filter (SUBSCRIPTIONS / null = All).
  Future<void> filterByTable(String? tableName) async {
    final current = state.value;
    if (current == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadAll(
          operation: current.selectedOperation,
          tableName: tableName,
        ));
  }

  /// Full reload — preserves no filters (clean refresh).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadAll());
  }
}

// ============================================================================
// Provider
// ============================================================================

final auditProvider =
    AsyncNotifierProvider<AuditNotifier, AuditState>(AuditNotifier.new);