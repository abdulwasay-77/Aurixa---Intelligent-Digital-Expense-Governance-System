/// AURIXA — Main Application Entry Point
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/storage_service.dart';

import 'features/auth/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';

import 'features/shell/app_shell.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'features/subscriptions/subscriptions_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/forecast/forecast_screen.dart';
import 'features/alerts/alerts_screen.dart';
import 'features/recommendations/recommendations_screen.dart';
import 'features/score_history/score_history_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/wallet/wallet_screen.dart';
import 'features/audit/audit_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  await windowManager.ensureInitialized();

  // Window opens at splash size (560×440), centered, no chrome.
  // The splash screen widens it to auth size (920×440) using a
  // frame-synced Ticker before navigating to login.
  const windowOptions = WindowOptions(
    size: Size(AppTheme.splashWindowWidth, AppTheme.splashWindowHeight),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.setMinimizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setClosable(false);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: MyApp()));
}

/// Phase 2 — Window chrome restoration for the authenticated app.
///
/// Replaces the old Phase-1 TODO. Per spec: after login/register, the
/// dashboard (and every authenticated screen, since they all share
/// AppShell) opens in TRUE FULLSCREEN — not just a resized chrome window.
///
/// `setFullScreen(true)` also implicitly restores resizable/minimizable/
/// maximizable/closable affordances on most platforms, but we set them
/// explicitly first so the window is in a sane, fully-interactive state
/// underneath the fullscreen flag (this matters if the user later exits
/// fullscreen via the hidden AppShell control — see
/// features/shell/app_shell.dart — they land in a normal resizable
/// window, not a relocked one).
///
/// Idempotent: GoRouter's ShellRoute rebuilds AppShell on every
/// authenticated navigation, but this is only called once per app-session
/// via a guard flag in AppShell itself, not from here — see AppShell's
/// initState. This function is the actual mutation; call site controls
/// the "only once on first authenticated entry" behavior.
Future<void> enterAppFullscreen() async {
  await windowManager.setResizable(true);
  await windowManager.setMinimizable(true);
  await windowManager.setMaximizable(true);
  await windowManager.setClosable(true);
  await windowManager.setFullScreen(true);
}

final _router = GoRouter(
  initialLocation: AppConstants.routeSplash,
  routes: [
    GoRoute(
      path: AppConstants.routeSplash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppConstants.routeLogin,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppConstants.routeRegister,
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    ShellRoute(
      // AppShell now owns entering fullscreen on first authenticated
      // build, plus the hidden hover-reveal exit-fullscreen control
      // (top-right of the window, see app_shell.dart).
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppConstants.routeDashboard,
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: AppConstants.routeSubscriptions,
          name: 'subscriptions',
          builder: (context, state) => const SubscriptionsScreen(),
        ),
        GoRoute(
          path: AppConstants.routeAnalytics,
          name: 'analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: AppConstants.routeForecast,
          name: 'forecast',
          builder: (context, state) => const ForecastScreen(),
        ),
        GoRoute(
          path: AppConstants.routeAlerts,
          name: 'alerts',
          builder: (context, state) => const AlertsScreen(),
        ),
        GoRoute(
          path: AppConstants.routeRecommendations,
          name: 'recommendations',
          builder: (context, state) => const RecommendationsScreen(),
        ),
        GoRoute(
          path: AppConstants.routeScoreHistory,
          name: 'scoreHistory',
          builder: (context, state) => const ScoreHistoryScreen(),
        ),
        GoRoute(
          path: AppConstants.routeProfile,
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppConstants.routeWallet,
          name: 'wallet',
          builder: (context, state) => const WalletScreen(),
        ),
        GoRoute(
          path: AppConstants.routeAudit,
          name: 'audit',
          builder: (context, state) => const AuditScreen(),
        ),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      routerConfig: _router,
    );
  }
}