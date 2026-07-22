/// AURIXA Application Constants
library;

class AppConstants {
  // API Configuration
  static const String apiBaseUrl = 'http://127.0.0.1:8000';
  static const String apiAuthPrefix = '/api/auth';
  
  // Full API Endpoints
  static const String apiLogin = '$apiBaseUrl$apiAuthPrefix/login';
  static const String apiRegister = '$apiBaseUrl$apiAuthPrefix/register';
  static const String apiRefresh = '$apiBaseUrl$apiAuthPrefix/refresh';
  static const String apiLogout = '$apiBaseUrl$apiAuthPrefix/logout';
  
  // Analytics Endpoints
  static const String apiScore = '$apiBaseUrl/api/analytics/score';
  static const String apiScoreTrend = '$apiBaseUrl/api/analytics/score/trend';
  static const String apiForecast = '$apiBaseUrl/api/analytics/forecast';
  static const String apiForecastCurrent = '$apiBaseUrl/api/analytics/forecast/current';
  static const String apiInsights = '$apiBaseUrl/api/analytics/insights';
  static const String apiCategories = '$apiBaseUrl/api/analytics/categories';
  static const String apiPatterns = '$apiBaseUrl/api/analytics/patterns';
  static const String apiMonthlySummary = '$apiBaseUrl/api/analytics/categories/monthly-summary';
  static const String apiDayOfWeek = '$apiBaseUrl/api/analytics/day-of-week';
  
  // Subscription Endpoints
  static const String apiSubscriptions = '$apiBaseUrl/api/subscriptions';
  
  // Alert Endpoints
  static const String apiAlerts = '$apiBaseUrl/api/alerts';
  static const String apiAlertsSummary = '$apiBaseUrl/api/alerts/summary';
  static const String apiAlertsDetectAnomalies = '$apiBaseUrl/api/alerts/detect-anomalies';

  // Recommendation Endpoints
  static const String apiRecommendations = '$apiBaseUrl/api/recommendations';

  // Wallet Endpoints
  static const String apiWallet = '$apiBaseUrl/api/wallet';

  // ✅ Phase 11 — Audit Trail Endpoints
  static const String apiAudit = '$apiBaseUrl/api/audit';
  static const String apiAuditSummary = '$apiBaseUrl/api/audit/summary';
  
  // Storage Keys
  static const String storageAccessToken = 'access_token';
  static const String storageRefreshToken = 'refresh_token';
  static const String storageUserId = 'user_id';
  static const String storageUserEmail = 'user_email';
  static const String storageUserFullName = 'user_full_name';
  static const String storageSidebarCollapsed = 'sidebar_collapsed';
  
  // Navigation Routes
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeDashboard = '/dashboard';
  static const String routeSubscriptions = '/subscriptions';
  static const String routeAnalytics = '/analytics';
  static const String routeForecast = '/forecast';
  static const String routeAlerts = '/alerts';
  static const String routeRecommendations = '/recommendations';
  static const String routeScoreHistory = '/score-history';
  static const String routeProfile = '/profile';
  static const String routeWallet = '/wallet';
  static const String routeAudit = '/audit';
  
  // App Info
  static const String appName = 'AURIXA';
  static const String appVersion = 'v2.3';
  static const String appTagline = 'Intelligent Digital Expense Governance';
}