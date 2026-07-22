/// Subscription State Management
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../models/subscription_models.dart';
import '../core/services/api_service.dart';
import '../core/constants/app_constants.dart';

// ============================================================================
// State Definition
// ============================================================================

class SubscriptionState {
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final List<SubscriptionResponse> subscriptions;
  final int totalCount;
  final int activeCount;
  final double totalMonthlySpend;
  final List<CategorySummary> categorySummary;

  const SubscriptionState({
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.subscriptions = const [],
    this.totalCount = 0,
    this.activeCount = 0,
    this.totalMonthlySpend = 0,
    this.categorySummary = const [],
  });

  SubscriptionState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    List<SubscriptionResponse>? subscriptions,
    int? totalCount,
    int? activeCount,
    double? totalMonthlySpend,
    List<CategorySummary>? categorySummary,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      subscriptions: subscriptions ?? this.subscriptions,
      totalCount: totalCount ?? this.totalCount,
      activeCount: activeCount ?? this.activeCount,
      totalMonthlySpend: totalMonthlySpend ?? this.totalMonthlySpend,
      categorySummary: categorySummary ?? this.categorySummary,
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

class SubscriptionNotifier extends AsyncNotifier<SubscriptionState> {
  @override
  Future<SubscriptionState> build() async {
    return await _loadSubscriptions();
  }

  Future<SubscriptionState> _loadSubscriptions() async {
    try {
      final results = await Future.wait([
        _fetchSubscriptions(),
        _fetchCategorySummary(),
      ]);

      final subs = results[0] as List<SubscriptionResponse>;
      final categories = results[1] as List<CategorySummary>;

      final activeSubs = subs.where((s) => s.isActive).toList();
      final totalMonthly = activeSubs.fold<double>(0, (sum, s) => sum + s.monthlyEquivalent);

      return SubscriptionState(
        isLoading: false,
        hasError: false,
        subscriptions: subs,
        totalCount: subs.length,
        activeCount: activeSubs.length,
        totalMonthlySpend: totalMonthly,
        categorySummary: categories,
      );
    } catch (e) {
      debugPrint('Subscription loading error: $e');
      return const SubscriptionState(
        isLoading: false,
        hasError: true,
        errorMessage: 'Failed to load subscriptions',
      );
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
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Subscriptions fetch error: $e');
      return [];
    }
  }

  Future<List<CategorySummary>> _fetchCategorySummary() async {
    try {
      final response = await ApiService.get('/api/subscriptions/categories/summary');
      if (response.statusCode == 200) {
        final data = response.data as List? ?? [];
        return data
            .map((json) => CategorySummary.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Category summary fetch error: $e');
      return [];
    }
  }

  // ==========================================================================
  // CRUD Operations
  // ==========================================================================

  Future<bool> createSubscription(CreateSubscriptionRequest request) async {
    try {
      final response = await ApiService.post(
        AppConstants.apiSubscriptions,
        data: request.toJson(),
      );

      if (response.statusCode == 201) {
        await refresh();
        return true;
      }
      return false;
    } on DioException catch (e) {
      debugPrint('Create subscription error: ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('Create subscription error: $e');
      return false;
    }
  }

  Future<bool> updateSubscription(int subId, UpdateSubscriptionRequest request) async {
    try {
      final response = await ApiService.put(
        '${AppConstants.apiSubscriptions}/$subId',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Update subscription error: $e');
      return false;
    }
  }

  Future<bool> cancelSubscription(int subId) async {
    try {
      final response = await ApiService.delete(
        '${AppConstants.apiSubscriptions}/$subId',
      );

      if (response.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Cancel subscription error: $e');
      return false;
    }
  }

  Future<bool> updateUsageScore(int subId, int usageScore) async {
    try {
      final response = await ApiService.patch(
        '${AppConstants.apiSubscriptions}/$subId/usage',
        data: {'usage_score': usageScore},
      );

      if (response.statusCode == 200) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Update usage score error: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadSubscriptions());
  }
}

// ============================================================================
// Provider
// ============================================================================

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);