/// AURIXA — Profile Provider
/// Manages user profile, preferences, password change, and logout state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/api_service.dart';
import '../core/services/storage_service.dart';

// ============================================================
// Data Models
// ============================================================

class UserInfo {
  final int userId;
  final String email;
  final String fullName;
  final String? phone;
  final String status;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const UserInfo({
    required this.userId,
    required this.email,
    required this.fullName,
    this.phone,
    required this.status,
    required this.createdAt,
    this.lastLogin,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['user_id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
    );
  }
}

class UserProfile {
  final int profileId;
  final int userId;
  final double monthlyIncome;
  final double savingTargetPct;
  final String riskTolerance;
  final String? lifestyleCategory;
  final String baseCurrencyCode;
  final String baseCurrencySymbol;
  final DateTime updatedAt;

  const UserProfile({
    required this.profileId,
    required this.userId,
    required this.monthlyIncome,
    required this.savingTargetPct,
    required this.riskTolerance,
    this.lifestyleCategory,
    required this.baseCurrencyCode,
    required this.baseCurrencySymbol,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      profileId: json['profile_id'] as int,
      userId: json['user_id'] as int,
      monthlyIncome: (json['monthly_income'] as num).toDouble(),
      savingTargetPct: (json['saving_target_pct'] as num).toDouble(),
      riskTolerance: json['risk_tolerance'] as String,
      lifestyleCategory: json['lifestyle_category'] as String?,
      baseCurrencyCode: json['base_currency_code'] as String,
      baseCurrencySymbol: json['base_currency_symbol'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class UserPreferences {
  final int prefId;
  final bool notifBudgetAlert;
  final bool notifBillingReminder;
  final bool notifAnomaly;
  final String theme;
  final String dashboardLayout;
  final bool biometricEnabled;

  const UserPreferences({
    required this.prefId,
    required this.notifBudgetAlert,
    required this.notifBillingReminder,
    required this.notifAnomaly,
    required this.theme,
    required this.dashboardLayout,
    required this.biometricEnabled,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      prefId: json['pref_id'] as int,
      notifBudgetAlert: json['notif_budget_alert'] as bool,
      notifBillingReminder: json['notif_billing_reminder'] as bool,
      notifAnomaly: json['notif_anomaly'] as bool,
      theme: json['theme'] as String,
      dashboardLayout: json['dashboard_layout'] as String,
      biometricEnabled: json['biometric_enabled'] as bool,
    );
  }

  UserPreferences copyWith({
    bool? notifBudgetAlert,
    bool? notifBillingReminder,
    bool? notifAnomaly,
    String? theme,
    bool? biometricEnabled,
  }) {
    return UserPreferences(
      prefId: prefId,
      notifBudgetAlert: notifBudgetAlert ?? this.notifBudgetAlert,
      notifBillingReminder: notifBillingReminder ?? this.notifBillingReminder,
      notifAnomaly: notifAnomaly ?? this.notifAnomaly,
      theme: theme ?? this.theme,
      dashboardLayout: dashboardLayout,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }
}

class ProfileState {
  final UserInfo? user;
  final UserProfile? profile;
  final UserPreferences? preferences;
  final bool isLoading;
  final String? errorMessage;

  const ProfileState({
    this.user,
    this.profile,
    this.preferences,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasData => user != null && profile != null && preferences != null;

  ProfileState copyWith({
    UserInfo? user,
    UserProfile? profile,
    UserPreferences? preferences,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      preferences: preferences ?? this.preferences,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// ============================================================
// Provider
// ============================================================

class ProfileNotifier extends AsyncNotifier<ProfileState> {
  @override
  Future<ProfileState> build() async {
    return _fetchAll();
  }

  Future<ProfileState> _fetchAll() async {
    

    final userRes = await ApiService.get('/api/users/me');
    final profileRes = await ApiService.get('/api/users/profile');
    final prefsRes = await ApiService.get('/api/users/preferences');

    final user = UserInfo.fromJson(userRes.data as Map<String, dynamic>);
    final profile = UserProfile.fromJson(profileRes.data as Map<String, dynamic>);
    final preferences =
        UserPreferences.fromJson(prefsRes.data as Map<String, dynamic>);

    return ProfileState(
      user: user,
      profile: profile,
      preferences: preferences,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchAll());
  }

  /// Update profile fields (income, saving %, risk tolerance, currency)
  Future<bool> updateProfile({
    double? monthlyIncome,
    double? savingTargetPct,
    String? riskTolerance,
    String? baseCurrencyCode,
  }) async {
    
    try {
      final body = <String, dynamic>{};
      if (monthlyIncome != null) body['monthly_income'] = monthlyIncome;
      if (savingTargetPct != null) body['saving_target_pct'] = savingTargetPct;
      if (riskTolerance != null) body['risk_tolerance'] = riskTolerance;
      if (baseCurrencyCode != null) body['base_currency_code'] = baseCurrencyCode;

      await ApiService.put('/api/users/profile', data: body);

      // Refresh state after successful update
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update notification preferences
  Future<bool> updatePreferences({
    bool? notifBudgetAlert,
    bool? notifBillingReminder,
    bool? notifAnomaly,
    String? theme,
    bool? biometricEnabled,
  }) async {
    
    try {
      final body = <String, dynamic>{};
      if (notifBudgetAlert != null) body['notif_budget_alert'] = notifBudgetAlert;
      if (notifBillingReminder != null)
        body['notif_billing_reminder'] = notifBillingReminder;
      if (notifAnomaly != null) body['notif_anomaly'] = notifAnomaly;
      if (theme != null) body['theme'] = theme;
      if (biometricEnabled != null) body['biometric_enabled'] = biometricEnabled;

      await ApiService.put('/api/users/preferences', data: body);

      // Optimistically update preferences in state without full reload
      final current = state.valueOrNull;
      if (current?.preferences != null) {
        final updated = current!.preferences!.copyWith(
          notifBudgetAlert: notifBudgetAlert,
          notifBillingReminder: notifBillingReminder,
          notifAnomaly: notifAnomaly,
          theme: theme,
          biometricEnabled: biometricEnabled,
        );
        state = AsyncData(current.copyWith(preferences: updated));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Change password
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    
    try {
      await ApiService.post('/api/users/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      return null; // null = success
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('incorrect')) {
        return 'Current password is incorrect';
      }
      return 'Failed to change password. Please try again.';
    }
  }

  /// Logout — clear token, navigate to login (caller handles navigation)
  Future<void> logout() async {
    try {
      
      final token = StorageService.getRefreshToken();
      if (token != null) {
        
        await ApiService.post('/api/auth/logout', data: {'refresh_token': token});
      }
    } catch (_) {
      // Ignore logout API errors — clear local storage regardless
    }
    await StorageService.clearAll();
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);