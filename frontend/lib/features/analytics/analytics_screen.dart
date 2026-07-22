/// BehaviorLens Screen — Full Analytics with Charts
/// Content only — Sidebar (and the app's only Scaffold) lives in
/// AppShell, matching the convention established by Dashboard and
/// SubVault.
///
/// Phase 4 rebuild:
///   - Removed the screen's own Scaffold/AppBar.
///   - Gradient hero header (BehaviorLens module color = brandPurple)
///     with the month selector built directly into it, matching the
///     SubVault header vocabulary.
///   - Summary card rebuilt on HoverCard with module-accent styling
///     instead of a plain Material Card.
///   - NEW: surfaces `state.patterns` (SpendingPatternResponse — month-
///     over-month % change per category), which AnalyticsProvider was
///     already fetching but no widget ever displayed. Same pattern as
///     the dashboard's insight fields and surfaced subscription data.
///   - All three chart widgets now get their own simulated-3D treatment
///     (see their individual file headers) and entrance-stagger via
///     HoverEntrance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../providers/analytics_provider.dart';
import '../../models/analytics_models.dart';
import 'widgets/category_donut_chart.dart';
import 'widgets/monthly_bar_chart.dart';
import 'widgets/spending_heatmap.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(analyticsProvider);

    return asyncState.when(
      loading: () => const _AnalyticsLoading(),
      error: (error, _) => _AnalyticsError(
        message: error.toString(),
        onRetry: _refresh,
      ),
      data: (state) {
        if (state.hasError) {
          return _AnalyticsError(
            message: state.errorMessage ?? 'Failed to load analytics',
            onRetry: _refresh,
          );
        }

        return RefreshIndicator(
          color: AppTheme.behaviorLens,
          backgroundColor: AppTheme.bgSurface,
          onRefresh: () async => _refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HoverEntrance(
                  index: 0,
                  child: _BehaviorLensHeader(
                    selectedMonth: state.selectedMonth,
                    onPreviousMonth: () => _changeMonth(state.selectedMonth, -1),
                    onNextMonth: () => _changeMonth(state.selectedMonth, 1),
                  ),
                ),
                const SizedBox(height: 20),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 760;
                    final donut = HoverEntrance(
                      index: 1,
                      child: CategoryDonutChart(
                        categories: state.currentMonthCategories,
                      ),
                    );
                    final summary = HoverEntrance(
                      index: 2,
                      child: _SummaryCard(state: state),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [donut, const SizedBox(height: 20), summary],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: donut),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: summary),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                HoverEntrance(
                  index: 3,
                  child: MonthlyBarChart(monthlyData: state.monthlySummary),
                ),
                const SizedBox(height: 20),

                if (state.patterns.isNotEmpty) ...[
                  HoverEntrance(
                    index: 4,
                    child: _SpendingPatternsCard(patterns: state.patterns),
                  ),
                  const SizedBox(height: 20),
                ],

                HoverEntrance(
                  index: 5,
                  child: SpendingHeatmap(dayOfWeekData: state.dayOfWeekData),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _changeMonth(DateTime current, int delta) {
    final newMonth = DateTime(current.year, current.month + delta, 1);
    ref.read(analyticsProvider.notifier).changeMonth(newMonth);
  }

  void _refresh() {
    ref.read(analyticsProvider.notifier).refresh();
  }
}

// ============================================================================
// Header — gradient hero band with title + month selector.
// ============================================================================
class _BehaviorLensHeader extends StatelessWidget {
  const _BehaviorLensHeader({
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  String _getMonthLabel(DateTime date) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.behaviorLens, AppTheme.brandIndigo],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCards),
        boxShadow: [
          BoxShadow(
            color: AppTheme.behaviorLens.withValues(alpha: 0.3),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;

          final titleBlock = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BehaviorLens',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Understand your spending patterns',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          );

          final monthSelector = Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppTheme.radiusInputs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HoverIconBadge(
                  icon: Icons.chevron_left_rounded,
                  glowColor: Colors.white,
                  size: 32,
                  onTap: onPreviousMonth,
                ),
                SizedBox(
                  width: 132,
                  child: Text(
                    _getMonthLabel(selectedMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                HoverIconBadge(
                  icon: Icons.chevron_right_rounded,
                  glowColor: Colors.white,
                  size: 32,
                  onTap: onNextMonth,
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 16),
                monthSelector,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              titleBlock,
              monthSelector,
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// Summary Card — Total / Categories / Top Category.
// ============================================================================
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});

  final AnalyticsState state;

  @override
  Widget build(BuildContext context) {
    final categories = state.currentMonthCategories;
    final total = categories.fold<double>(0, (sum, c) => sum + c.totalAmount);
    final topCategory = categories.isNotEmpty
        ? categories.reduce((a, b) => a.totalAmount > b.totalAmount ? a : b)
        : null;

    return HoverCard(
      glowColor: AppTheme.behaviorLens,
      size: HoverSize.subtle,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HoverIconBadge(
                icon: Icons.insights_rounded,
                glowColor: AppTheme.behaviorLens,
                size: 30,
              ),
              const SizedBox(width: 10),
              const Text(
                'Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSummaryItem(
            label: 'Total Spend',
            value: '\$${total.toStringAsFixed(2)}',
            color: AppTheme.textPrimary,
            big: true,
          ),
          const Divider(height: 28),
          _buildSummaryItem(
            label: 'Categories',
            value: '${categories.length}',
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            label: 'Top Category',
            value: topCategory?.categoryName ?? 'None',
            color: topCategory != null ? topCategory.color : AppTheme.textMuted,
          ),
          if (topCategory != null) ...[
            const SizedBox(height: 12),
            _buildSummaryItem(
              label: 'Top Amount',
              value: '\$${topCategory.totalAmount.toStringAsFixed(2)}',
              color: topCategory.color,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required Color color,
    bool big = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 22 : 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// NEW — Spending Patterns Card. Surfaces SpendingPatternResponse
// (month-over-month % change per category), fetched by the provider but
// previously dropped entirely. Each row is a HoverListItem with an
// up/down trend chip.
// ============================================================================
class _SpendingPatternsCard extends StatelessWidget {
  const _SpendingPatternsCard({required this.patterns});

  final List<SpendingPatternResponse> patterns;

  @override
  Widget build(BuildContext context) {
    final sorted = List<SpendingPatternResponse>.from(patterns)
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    final visible = sorted.take(6).toList();

    return HoverCard(
      glowColor: AppTheme.behaviorLens,
      size: HoverSize.subtle,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HoverIconBadge(
                icon: Icons.trending_up_rounded,
                glowColor: AppTheme.behaviorLens,
                size: 30,
              ),
              const SizedBox(width: 10),
              const Text(
                'Spending Patterns',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              const Text(
                'vs last month',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(visible.length, (i) {
            final p = visible[i];
            final change = p.momChangePct;
            final isUp = (change ?? 0) > 0;
            final isFlat = change == null || change == 0;
            final trendColor = isFlat
                ? AppTheme.textMuted
                : (isUp ? AppTheme.danger : AppTheme.success);

            return HoverListItem(
              glowColor: AppTheme.behaviorLens,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              // Reduced from the default HoverSize.small (1.10x) — these
              // rows are wide with several inline elements (category
              // name, txn count, amount, trend chip), so the punchy zoom
              // felt like too much movement at once. Same gentler tier
              // subscription cards use, for the same reason.
              size: HoverSize.subtle,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.categoryName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${p.txnCount} txns · avg \$${p.avgTxnAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${p.totalSpent.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusBadges),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isFlat)
                          Icon(
                            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 12,
                            color: trendColor,
                          ),
                        const SizedBox(width: 2),
                        Text(
                          isFlat ? '—' : '${change.abs().toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: trendColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================================
// Loading / Error states.
// ============================================================================
class _AnalyticsLoading extends StatelessWidget {
  const _AnalyticsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(
          strokeWidth: 3.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.behaviorLens),
        ),
      ),
    );
  }
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({required this.message, required this.onRetry});

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
              child: const Icon(Icons.error_outline_rounded, size: 32, color: AppTheme.danger),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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