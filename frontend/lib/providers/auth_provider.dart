/// Authentication State Management using Riverpod
/// NO auto-login. User must manually login each time.
///
/// BUG FIX (lethal — cross-account data leak):
///   Every per-feature provider (dashboard, subscriptions, wallet, alerts,
///   analytics, audit, forecast, profile, recommendations, score_history) is
///   an AsyncNotifierProvider. AsyncNotifierProvider caches its build()
///   result for the lifetime of the ProviderContainer and will NOT re-run
///   unless ref.invalidate()/refresh() is called explicitly — it has no idea
///   "the logged-in user changed" is a reason to refetch.
///
///   Most screens papered over this by force-refreshing in initState()
///   every time they mount. DashboardScreen didn't (it's a plain
///   ConsumerWidget with no initState), so it kept showing whichever
///   account's data was cached the last time build() ran — including data
///   from a DIFFERENT account after a user switch.
///
///   Real fix: invalidate every user-scoped provider right here, at the one
///   place that actually knows when the active account has changed —
///   successful login and logout. This makes the leak structurally
///   impossible regardless of whether any individual screen remembers to
///   refresh itself, and it doesn't rely on cache-busting band-aids in
///   every screen's initState.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../models/auth_models.dart';
import '../core/services/api_service.dart';
import '../core/services/storage_service.dart';
import '../core/constants/app_constants.dart';

import 'alert_provider.dart';
import 'analytics_provider.dart';
import 'audit_provider.dart';
import 'dashboard_provider.dart';
import 'forecast_provider.dart';
import 'profile_provider.dart';
import 'recommendation_provider.dart';
import 'score_history_provider.dart';
import 'subscription_provider.dart';
import 'wallet_provider.dart';

// ============================================================================
// State Definition
// ============================================================================

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserResponse? user;
  final String? error;
  final String? accessToken;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
    this.accessToken,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserResponse? user,
    String? error,
    String? accessToken,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error ?? this.error,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}

// ============================================================================
// Provider
// ============================================================================

class AuthNotifier extends StateNotifier<AuthState> {
  // Needs a Ref so it can invalidate other providers when the active
  // account changes. Passed in from the provider definition below.
  AuthNotifier(this._ref) : super(AuthState()) {
    // NO AUTO-LOGIN - Do nothing on startup
    // User must manually login each time
  }

  final Ref _ref;

  /// Invalidates every provider that holds data scoped to a single user
  /// account. Forces each one to throw away its cached AsyncValue, so the
  /// NEXT time any screen watches it, build() runs fresh against whichever
  /// account is currently logged in (the api interceptor reads the token
  /// from StorageService per-request, so it always picks up the right one).
  ///
  /// IMPORTANT: any new feature provider that holds per-user data must be
  /// added to this list. This is now the single source of truth for
  /// "what gets wiped when the account changes" — don't rely on individual
  /// screens' initState to refresh as the safety net.
  void _invalidateUserScopedProviders() {
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(subscriptionProvider);
    _ref.invalidate(walletProvider);
    _ref.invalidate(alertProvider);
    _ref.invalidate(analyticsProvider);
    _ref.invalidate(auditProvider);
    _ref.invalidate(forecastProvider);
    _ref.invalidate(profileProvider);
    _ref.invalidate(recommendationProvider);
    _ref.invalidate(scoreHistoryProvider);
  }

  Future<void> fetchCurrentUser() async {
    try {
      final response = await ApiService.get('/api/users/me');
      if (response.statusCode == 200) {
        final user = UserResponse.fromJson(response.data);
        state = state.copyWith(
          user: user,
          isAuthenticated: true,
          error: null,
        );
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final request = LoginRequest(email: email, password: password);
      debugPrint('📤 Login request: ${request.toJson()}');

      final response = await ApiService.post(
        AppConstants.apiLogin,
        data: request.toJson(),
      );

      debugPrint('📥 Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final tokenResponse = TokenResponse.fromJson(response.data);

        // Store tokens (only for API requests, not for auto-login)
        await StorageService.setAccessToken(tokenResponse.accessToken);
        await StorageService.setRefreshToken(tokenResponse.refreshToken);

        // BUG FIX: wipe every cached per-user provider BEFORE anything
        // downstream can read them. This is what actually prevents the
        // dashboard (or any other screen) from showing the previous
        // account's data after a user switch. Must happen after the new
        // tokens are stored (so the eventual rebuild authenticates as the
        // new user) but before we report success.
        _invalidateUserScopedProviders();

        // Fetch user info
        await fetchCurrentUser();

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          accessToken: tokenResponse.accessToken,
          error: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Login failed. Please check your credentials.',
        );
        return false;
      }
    } on DioException catch (e) {
      debugPrint('❌ Dio error: ${e.response?.data}');
      debugPrint('❌ Dio status: ${e.response?.statusCode}');

      String errorMessage = 'Network error. Please try again.';
      if (e.response?.statusCode == 401) {
        errorMessage = 'Invalid email or password.';
      } else if (e.response?.data != null) {
        try {
          final errorData = e.response?.data;
          if (errorData is Map && errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          }
        } catch (_) {}
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred.',
      );
      return false;
    }
  }

  Future<bool> register(RegisterRequest request) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('📤 Register request: ${request.toJson()}');

      final response = await ApiService.post(
        AppConstants.apiRegister,
        data: request.toJson(),
      );

      debugPrint('📥 Register response status: ${response.statusCode}');
      debugPrint('📥 Register response data: ${response.data}');

      if (response.statusCode == 201) {
        debugPrint('✅ Registration successful, auto-logging in...');
        // login() already invalidates every user-scoped provider, so a
        // freshly-registered account never inherits a previous account's
        // cached state either.
        return await login(request.email, request.password);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Registration failed. Please try again.',
        );
        return false;
      }
    } on DioException catch (e) {
      debugPrint('❌ Dio error: ${e.response?.data}');
      debugPrint('❌ Dio status: ${e.response?.statusCode}');

      String errorMessage = 'Registration failed. Please try again.';
      if (e.response?.data != null) {
        try {
          final errorData = e.response?.data;
          if (errorData is Map && errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          }
        } catch (_) {}
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = StorageService.getRefreshToken();
      if (refreshToken != null) {
        await ApiService.post(AppConstants.apiLogout, data: {
          'refresh_token': refreshToken,
        });
      }
    } catch (e) {
      debugPrint('Logout API error: $e');
    }

    await StorageService.clearAll();

    // BUG FIX: also wipe on logout, not just on the next login. This means
    // a logged-out session holds zero residual financial data in memory —
    // important if the app is ever left open on a login screen — and it
    // means whoever logs in next starts from a guaranteed-clean slate even
    // if login() were ever called from a code path that skipped its own
    // invalidation (defense in depth).
    _invalidateUserScopedProviders();

    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});