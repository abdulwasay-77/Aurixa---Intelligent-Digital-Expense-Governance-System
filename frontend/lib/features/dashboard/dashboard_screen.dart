/// Dashboard Screen — Phase 2 UI Enhancement
///
/// Visual language per the AURIXA Nebula spec:
///   - Gradient hero header (brandBlue → brandIndigo → brandPurple) greets
///     the user by name, surfaces the headline "monthly spend" number,
///     and carries the score badge — this is the first thing the eye
///     hits on a fullscreen dashboard, so it needs to feel like a real
///     hero, not a label stack.
///   - Every card is a HoverCard with its module's default glow color;
///     status-bearing cards (alerts) override per the
///     "module default, status override" rule.
///   - Entire grid cascades in on load via HoverEntrance, staggered
///     ~45ms per item — wrapper handles entrance, inner HoverCard handles
///     hover scale, per the locked "never share a Transform" rule.
/// Sidebar lives in AppShell — this screen is content-only.
///
/// BUG FIX (lethal — cross-account data leak):
///   dashboardProvider is an AsyncNotifierProvider, which caches its
///   build() result for the lifetime of the app and only reloads on an
///   explicit refresh()/invalidate(). Every other data screen in this app
///   (alerts, analytics, audit, forecast, profile, recommendations,
///   score_history, subscriptions, wallet) is a ConsumerStatefulWidget that
///   force-refreshes its provider in initState(). This screen used to be a
///   plain ConsumerWidget with no initState, so it never forced that
///   refresh — it just displayed whatever was cached, which could be a
///   PREVIOUS account's financial data after a user switch (login → logout
///   → different login).
///
///   The root cause is now fixed centrally in auth_provider.dart, which
///   invalidates dashboardProvider (and every other user-scoped provider)
///   on login and logout. Converting this screen to a
///   ConsumerStatefulWidget with its own mount-time refresh is a second,
///   independent line of defense: it brings Dashboard in line with the
///   established pattern used everywhere else in the codebase, so it's no
///   longer the one screen that silently depends on a cache invalidation
///   happening somewhere else to stay correct.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import 'widgets/score_core_widget.dart';
import 'widgets/velocity_gauge_widget.dart';
import 'widgets/insight_card_widget.dart';
import 'widgets/upcoming_billing_widget.dart';
import 'widgets/alert_summary_widget.dart';
import 'widgets/quick_stats_row.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // BUG FIX: force a fresh fetch every time this screen mounts, same as
    // every other data screen in the app (alerts, analytics, audit,
    // forecast, profile, recommendations, score_history, subscriptions,
    // wallet all do this). Without it, AsyncNotifierProvider's caching
    // means this screen can show a previous, different account's data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider.select((s) => s.user));

    return asyncState.when(
      loading: () => const _DashboardLoading(),
      error: (error, _) => _DashboardError(
        message: error.toString(),
        onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
      ),
      data: (dashboardState) {
        if (dashboardState.hasError) {
          return _DashboardError(
            message: dashboardState.errorMessage ?? 'Failed to load dashboard',
            onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
          );
        }

        return RefreshIndicator(
          color: AppTheme.brandBlue,
          backgroundColor: AppTheme.bgSurface,
          onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HoverEntrance(
                  index: 0,
                  child: _HeroHeader(
                    userName: user?.fullName,
                    monthlySpend: dashboardState.totalMonthlySpend,
                    score: dashboardState.score,
                  ),
                ),
                const SizedBox(height: 22),

                HoverEntrance(
                  index: 1,
                  child: QuickStatsRow(
                    activeSubscriptions: dashboardState.upcomingBilling.length,
                    monthlySpend: dashboardState.totalMonthlySpend,
                    forecast: dashboardState.forecast,
                    alertSummary: dashboardState.alertSummary,
                  ),
                ),
                const SizedBox(height: 22),

                // Primary row — Financial Health ring + Budget velocity gauge.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 760;
                    final scoreCard = HoverEntrance(
                      index: 2,
                      child: ScoreCoreWidget(score: dashboardState.score),
                    );
                    final velocityCard = HoverEntrance(
                      index: 3,
                      child: VelocityGaugeWidget(
                        forecast: dashboardState.forecast,
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          scoreCard,
                          const SizedBox(height: 20),
                          velocityCard,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: scoreCard),
                        const SizedBox(width: 20),
                        Expanded(child: velocityCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                HoverEntrance(
                  index: 4,
                  child: InsightCardWidget(insights: dashboardState.insights),
                ),
                const SizedBox(height: 20),

                // Secondary row — Upcoming billing + RiskRadar summary.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 760;
                    final billingCard = HoverEntrance(
                      index: 5,
                      child: UpcomingBillingWidget(
                        subscriptions: dashboardState.upcomingBilling,
                      ),
                    );
                    final alertsCard = HoverEntrance(
                      index: 6,
                      child: AlertSummaryWidget(
                        alertSummary: dashboardState.alertSummary,
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          billingCard,
                          const SizedBox(height: 20),
                          alertsCard,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: billingCard),
                        const SizedBox(width: 20),
                        Expanded(child: alertsCard),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Hero Header — gradient banner with greeting, monthly spend, score badge.
// ============================================================================
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.userName,
    required this.monthlySpend,
    required this.score,
  });

  final String? userName;
  final int monthlySpend;
  final dynamic score; // FinancialScoreResponse?

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (userName == null || userName!.trim().isEmpty)
        ? 'there'
        : userName!.trim().split(' ').first;
    final healthScore = score?.financialHealthScore;
    final scoreLabel = score?.scoreLabel as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.brandGradient,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCards),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandIndigo.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft decorative glow circles for depth — purely ambient.
          Positioned(
            right: -30,
            top: -50,
            child: _GlowCircle(size: 180, opacity: 0.16),
          ),
          Positioned(
            right: 90,
            bottom: -60,
            child: _GlowCircle(size: 120, opacity: 0.12),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 620;

              final greetingBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_greeting,',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This month: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      Text(
                        '\$$monthlySpend',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        ' across active subscriptions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final scoreBadge = healthScore == null
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            healthScore.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            scoreLabel ?? 'SCORE',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    greetingBlock,
                    if (healthScore != null) ...[
                      const SizedBox(height: 18),
                      scoreBadge,
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: greetingBlock),
                  if (healthScore != null) scoreBadge,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

// ============================================================================
// Loading state — branded spinner, not a bare default-color one.
// ============================================================================
class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(
          strokeWidth: 3.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandBlue),
        ),
      ),
    );
  }
}

// ============================================================================
// Error state — consistent with the rest of the app's danger styling.
// ============================================================================
class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppTheme.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            HoverButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}