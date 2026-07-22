/// Spending Heatmap — Day of week spending patterns
///
/// Phase 4 — BehaviorLens visual overhaul. This widget uses pure Flutter
/// primitives (Container/FractionallySizedBox), not fl_chart, so none of
/// the package-version caution from the donut/bar charts applies here —
/// full freedom to use gradients, shadows, and hover response.
///   - Each day's bar now draws with a depth gradient (lighter highlight
///     at the top edge, full color at the bottom) plus a soft drop
///     shadow UNDER the filled portion only — reads as a raised,
///     rounded bar sitting above the track, not a flat color fill.
///   - Each row is wrapped in MouseRegion: hovering lifts that row's bar
///     slightly (translateY) and brightens it, with neighboring rows
///     unaffected — a per-row "pop," consistent with the rest of the
///     app's hover vocabulary but tuned for a thin horizontal bar rather
///     than a card.
///   - Contrast fix: the original intensity scale started as low as
///     alpha 0.2 over a near-white track, which read as barely-there
///     for low-spend days. Rescaled the floor to alpha 0.35 minimum
///     (still visually distinct from the alpha 0.2 a casual reader
///     could otherwise want lower) and replaced the previous "track"
///     fill (pure bgElevated white) with a faint tinted track so even
///     an empty bar has a visible boundary against the card surface.
///   - Card uses HoverCard(size: HoverSize.subtle) consistent with the
///     other two BehaviorLens charts.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class SpendingHeatmap extends StatefulWidget {
  final List<DayOfWeekSpend> dayOfWeekData;

  const SpendingHeatmap({super.key, required this.dayOfWeekData});

  @override
  State<SpendingHeatmap> createState() => _SpendingHeatmapState();
}

class _SpendingHeatmapState extends State<SpendingHeatmap> {
  int _hoveredIndex = -1;

  // Draw-in: bars grow from zero width to their real width on first
  // build — distinct technique from the fl_chart-driven draw-ins on the
  // donut/bar charts (those rely on the library's own swap animation;
  // here it's a plain AnimatedContainer width tween since this widget
  // has no chart library underneath it).
  bool _hasDrawnIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hasDrawnIn = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dayOfWeekData.isEmpty) {
      return _buildEmptyState();
    }

    final dayOrder = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final sortedData = dayOrder.map((day) {
      return widget.dayOfWeekData.firstWhere(
        (d) => d.dayOfWeek.toUpperCase() == day,
        orElse: () => DayOfWeekSpend(
          dayOfWeek: day,
          totalAmount: 0,
          transactionCount: 0,
        ),
      );
    }).toList();

    final maxSpend = sortedData.fold<double>(
      0,
      (max, d) => d.totalAmount > max ? d.totalAmount : max,
    );

    return HoverCard(
      glowColor: AppTheme.behaviorLens,
      size: HoverSize.subtle,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending by Day of Week',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedData.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final double percentage =
                maxSpend > 0 ? (day.totalAmount / maxSpend) : 0.0;
            final double clampedPercentage = percentage.clamp(0.05, 1.0);
            final bool hasData = day.totalAmount > 0;
            final isHovered = index == _hoveredIndex;

            return MouseRegion(
              onEnter: hasData ? (_) => setState(() => _hoveredIndex = index) : null,
              onExit: hasData ? (_) => setState(() => _hoveredIndex = -1) : null,
              child: AnimatedContainer(
                duration: AppTheme.hoverDuration,
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(
                  isHovered ? 3 : 0,
                  0,
                  0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        _getDayLabel(day.dayOfWeek),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isHovered ? FontWeight.w600 : FontWeight.normal,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          // Faint tinted track instead of flat white —
                          // gives even an empty bar a visible boundary.
                          color: AppTheme.behaviorLens.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.borderColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: hasData
                            ? AnimatedFractionallySizedBox(
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.centerLeft,
                                widthFactor: _hasDrawnIn ? clampedPercentage : 0.0,
                                child: AnimatedContainer(
                                  duration: AppTheme.hoverDuration,
                                  curve: Curves.easeOut,
                                  margin: EdgeInsets.symmetric(
                                    vertical: isHovered ? 1 : 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        _getIntensityColor(percentage, lightened: true),
                                        _getIntensityColor(percentage),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getIntensityColor(percentage).withValues(
                                          alpha: isHovered ? 0.55 : 0.30,
                                        ),
                                        blurRadius: isHovered ? 10 : 5,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 60,
                      child: Text(
                        hasData ? '\$${day.totalAmount.toStringAsFixed(0)}' : '\$0',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: hasData ? FontWeight.w600 : FontWeight.normal,
                          color: hasData ? AppTheme.textPrimary : AppTheme.textMuted,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          _buildStatsRow(sortedData, maxSpend),
        ],
      ),
    );
  }

  String _getDayLabel(String dayCode) {
    const dayMap = {
      'MON': 'Monday',
      'TUE': 'Tuesday',
      'WED': 'Wednesday',
      'THU': 'Thursday',
      'FRI': 'Friday',
      'SAT': 'Saturday',
      'SUN': 'Sunday',
    };
    return dayMap[dayCode.toUpperCase()] ?? dayCode;
  }

  // Contrast fix: floor raised from 0.2 to 0.35 alpha so even the
  // lightest non-zero day reads clearly against the card surface,
  // rather than nearly blending into the track. `lightened` produces
  // the highlighted top-edge color for the depth gradient.
  Color _getIntensityColor(double intensity, {bool lightened = false}) {
    late final Color base;
    if (intensity < 0.2) {
      base = AppTheme.behaviorLens.withValues(alpha: 0.35);
    } else if (intensity < 0.4) {
      base = AppTheme.behaviorLens.withValues(alpha: 0.5);
    } else if (intensity < 0.6) {
      base = AppTheme.behaviorLens.withValues(alpha: 0.68);
    } else if (intensity < 0.8) {
      base = AppTheme.behaviorLens.withValues(alpha: 0.85);
    } else {
      base = AppTheme.behaviorLens;
    }
    return lightened ? Color.lerp(base, Colors.white, 0.3)! : base;
  }

  Widget _buildStatsRow(List<DayOfWeekSpend> data, double maxSpend) {
    final total = data.fold<double>(0, (sum, d) => sum + d.totalAmount);
    final activeDays = data.where((d) => d.totalAmount > 0).length;
    final avg = activeDays > 0 ? total / activeDays : 0;
    final maxDay = data.isNotEmpty
        ? data.reduce((a, b) => a.totalAmount > b.totalAmount ? a : b)
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.behaviorLens.withValues(alpha: 0.08),
            AppTheme.brandBlue.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            label: 'Total Weekly',
            value: '\$${total.toStringAsFixed(0)}',
            color: AppTheme.textPrimary,
          ),
          _buildStatItem(
            label: 'Daily Average',
            value: '\$${avg.toStringAsFixed(0)}',
            color: AppTheme.textSecondary,
          ),
          _buildStatItem(
            label: 'Highest Day',
            value: maxDay != null ? _getDayLabel(maxDay.dayOfWeek) : 'None',
            color: AppTheme.behaviorLens,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return HoverCard(
      glowColor: AppTheme.behaviorLens,
      size: HoverSize.subtle,
      scaleEnabled: false,
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.behaviorLens.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                size: 32,
                color: AppTheme.behaviorLens,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No transaction data available for this month',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add some debit transactions to see day-of-week patterns',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}