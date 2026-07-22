/// Monthly Bar Chart — 6-month spending trends
///
/// Phase 4 — BehaviorLens visual overhaul (simulated 3D, no new
/// dependency — see category_donut_chart.dart header for the full
/// rationale on why this is gradients/shadows/touch-response rather
/// than a real 3D renderer):
///   - Each bar now draws with a vertical gradient (lighter at the top,
///     true category color at the base) via BarChartRodData.gradient —
///     confirmed present on the pinned fl_chart ^0.68.0 (this property
///     predates the version, unlike PieChartSectionData.gradient which
///     does not — see the donut chart for that distinction). This reads
///     as a lit, rounded column rather than a flat rectangle.
///   - The background "track" each bar sits in front of
///     (backDrawRodData) also gets a subtle gradient instead of a flat
///     fill, so the recessed area reads as a groove, not a flat panel.
///   - Touching/hovering a bar (via BarTouchData) brightens it and
///     reports the exact value in a styled tooltip — fl_chart's own
///     touch system, no custom gesture handling needed.
///   - Draw-in: bars render at toY: 0 on first frame, then swap to real
///     values — BarChart animates the height growth by default.
///   - Card uses HoverCard(size: HoverSize.subtle) — same reasoning as
///     the donut: enough zoom to feel alive without fighting the bars'
///     own internal hover/touch response.
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class MonthlyBarChart extends StatefulWidget {
  final List<MonthlyCategorySummary> monthlyData;

  const MonthlyBarChart({super.key, required this.monthlyData});

  @override
  State<MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<MonthlyBarChart> {
  int _touchedGroupIndex = -1;

  // Draw-in: see category_donut_chart.dart for the full rationale —
  // first frame renders bars at zero height, then a post-frame setState
  // swaps to real values and BarChart's default swap animation grows
  // each bar in.
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
    if (widget.monthlyData.isEmpty) {
      return _buildEmptyState();
    }

    final sortedData = List<MonthlyCategorySummary>.from(widget.monthlyData)
      ..sort((a, b) => a.month.compareTo(b.month));

    final maxValue = sortedData.fold<double>(0, (max, m) => m.totalSpend > max ? m.totalSpend : max);
    final yMax = (maxValue * 1.2).ceilToDouble();

    return HoverCard(
      glowColor: AppTheme.behaviorLens,
      size: HoverSize.subtle,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Spending Trend',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (sortedData.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.behaviorLens.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusBadges),
                  ),
                  child: Text(
                    'Top: ${sortedData.last.topCategory}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.behaviorLens,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: yMax,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.spot == null) {
                        _touchedGroupIndex = -1;
                        return;
                      }
                      _touchedGroupIndex = response.spot!.touchedBarGroupIndex;
                    });
                  },
                  touchTooltipData: BarTouchTooltipData(
                    // getTooltipColor confirmed correct for this pinned
                    // version: the older tooltipBgColor was removed by
                    // 0.67.0 per fl_chart's own migration guide (and
                    // confirmed broken specifically on ^0.68.0 in a
                    // real-world bug report). Not using
                    // tooltipBorderRadius — its introduction timing
                    // relative to 0.68.0 couldn't be confirmed, and it's
                    // purely cosmetic, so it's safer to omit.
                    getTooltipColor: (group) => AppTheme.textPrimary,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '\$${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sortedData.length) {
                          return const SizedBox.shrink();
                        }
                        final isTouched = index == _touchedGroupIndex;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _getMonthLabel(sortedData[index].month),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isTouched ? FontWeight.w700 : FontWeight.normal,
                              color: isTouched ? AppTheme.textPrimary : AppTheme.textSecondary,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toInt()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yMax / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.borderColor.withValues(alpha: 0.4),
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: sortedData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  // FIX (carried over): was comparing against
                  // `sortedData.last.totalSpend`, which always
                  // highlighted the most recent month regardless of how
                  // much was spent — despite the variable being named
                  // `isPeak`/`isTop`. Compares against `maxValue` (the
                  // highest spend across all months shown) so the bar
                  // that lights up is genuinely the peak-spending month.
                  final isPeak = data.totalSpend == maxValue;
                  final isTouched = index == _touchedGroupIndex;

                  // Draw-in: bars sit at zero height until the first
                  // post-frame swap, then BarChart's default swap
                  // animation grows them to their real toY.
                  final barHeight = _hasDrawnIn ? data.totalSpend : 0.0;

                  // Simulated 3D: a top-to-bottom gradient per bar —
                  // lighter at the top (catching light), full color at
                  // the base — plus a brighter, wider rod when touched.
                  // BarChartRodData.gradient is confirmed present on the
                  // pinned fl_chart version (predates 0.68.0).
                  final baseColor = isPeak ? AppTheme.behaviorLens : AppTheme.brandIndigo.withValues(alpha: 0.55);
                  final topColor = isTouched
                      ? Color.lerp(baseColor, Colors.white, 0.45)!
                      : Color.lerp(baseColor, Colors.white, 0.25)!;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: barHeight,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [topColor, baseColor],
                        ),
                        width: isTouched ? 24 : 20,
                        borderRadius: BorderRadius.circular(6),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: yMax,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.bgElevated,
                              AppTheme.bgBase.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthLabel(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[date.month - 1];
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
                Icons.bar_chart_rounded,
                size: 32,
                color: AppTheme.behaviorLens,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No monthly trend data available',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}