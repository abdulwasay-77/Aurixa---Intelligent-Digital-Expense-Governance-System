/// Velocity Chart Widget — Line chart showing daily spending rate
///
/// Phase 5 — VelocityEngine visual overhaul. Simulated 3D depth, same
/// "no new dependency" approach used for the BehaviorLens charts (see
/// category_donut_chart.dart for the full rationale on gradients/
/// shadows/touch-response standing in for real 3D rendering):
///   - The historical line's area fill (`BarAreaData.gradient`) is now a
///     real top-to-bottom gradient instead of a flat translucent tint —
///     confirmed safe to use: `BarAreaData.gradient` is a LINE-chart
///     area property, unrelated to `PieChartSectionData.gradient` (the
///     one that was NOT available pre-0.71.0 on the donut chart) and
///     unrelated to `BarChartRodData.gradient` (confirmed safe on the
///     bar chart) — area-fill gradients on LineChart predate the pinned
///     ^0.68.0 constraint. Checked deliberately rather than assumed,
///     per the version-safety lesson from Phase 4.
///   - The "today" dot (where historical data hands off to the
///     projection) gets a soft colored glow — a BoxShadow-style halo
///     achieved with a slightly larger, lower-opacity dot painted
///     underneath via `FlDotData`'s ability to return a custom painter,
///     not a literal BoxShadow (fl_chart dot painters don't expose one)
///     — same "glow vocabulary, adapted to the canvas" approach the
///     donut chart uses for its drop-shadow puck.
///   - Draw-in: the chart renders with all historical points collapsed
///     to the chart's baseline (y: 0) on the first frame, then swaps to
///     the real generated spots — LineChart animates the curve growth
///     by default on a data swap, same technique as the donut/bar
///     draw-ins.
///   - Card uses HoverCard(size: HoverSize.subtle) — same reasoning as
///     every BehaviorLens chart card: enough zoom to feel alive without
///     fighting the chart's own internal touch/tooltip response.
///   - Carried forward unchanged: the explicit `List<FlSpot>` /
///     `<FlSpot>[]` type-annotation fix for the projection-spots
///     ternary (still required — removing it reintroduces the
///     `List<dynamic>` compile failure documented previously), and the
///     `daysPassed`/`safeDaysPassed` clamping logic.
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class VelocityChart extends StatefulWidget {
  final CurrentMonthForecast? forecast;

  const VelocityChart({super.key, this.forecast});

  @override
  State<VelocityChart> createState() => _VelocityChartState();
}

class _VelocityChartState extends State<VelocityChart> {
  // Draw-in: see file header. First frame renders the historical line
  // collapsed to the baseline, then a post-frame setState swaps in the
  // real generated spots and LineChart's default swap animation grows
  // the curve up from zero.
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
    final velocity = widget.forecast?.currentVelocity ?? 0;
    final daysRemaining = widget.forecast?.daysRemaining ?? 30;
    final daysPassed = 30 - daysRemaining;

    return HoverCard(
      glowColor: AppTheme.velocityEngine,
      size: HoverSize.subtle,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spend Velocity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.velocityEngine.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${velocity.toStringAsFixed(0)}/day',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.velocityEngine,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: _buildLineChart(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.velocityEngine,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Actual', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(width: 14),
                  Container(
                    width: 8,
                    height: 2,
                    color: AppTheme.warning.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  const Text('Projected', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
              Text(
                'Day ${daysPassed + 1} of 30',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    final daysRemaining = widget.forecast?.daysRemaining ?? 30;
    final velocity = widget.forecast?.currentVelocity ?? 0;

    if (velocity == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insights_rounded, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 8),
            const Text(
              'No velocity data yet',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const Text(
              'Start tracking to see your spending velocity',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    // Clamp daysPassed to valid range 0-29 (carried forward unchanged).
    final daysPassed = (30 - daysRemaining).clamp(0, 29);

    // Generate realistic daily velocity data (30 days) — unchanged logic.
    final spots = List.generate(30, (index) {
      double value;
      if (index < daysPassed) {
        value = velocity * (0.7 + (index / math.max(daysPassed, 1)) * 0.6);
        value = value * (0.85 + (index % 3) * 0.1);
      } else {
        value = velocity * (1.0 + (index - daysPassed) * 0.02);
      }
      return FlSpot(index.toDouble(), value.clamp(0, math.max(velocity * 1.5, 1)));
    });

    final safeDaysPassed = daysPassed.clamp(0, spots.length - 1);
    final realHistoricalSpots = spots.sublist(0, safeDaysPassed + 1);
    final maxY = spots.fold<double>(0, (max, spot) => spot.y > max ? spot.y : max);

    // Draw-in: while not yet drawn in, collapse every historical point to
    // the baseline (y: 0) so the first paint is a flat line at the
    // bottom, then the post-frame setState swaps in the real values and
    // LineChart's default swap animation grows the curve upward — same
    // "render at zero, swap on next frame" technique as the donut/bar
    // draw-ins, adapted to a line's baseline instead of a wedge/bar
    // height.
    final historicalSpots = _hasDrawnIn
        ? realHistoricalSpots
        : realHistoricalSpots.map((s) => FlSpot(s.x, 0)).toList();

    // Build line bars data list.
    final List<LineChartBarData> lineBarsData = [];

    // 1. Historical data (always present) — gradient area fill underneath
    // simulates a lit, raised ribbon rather than a flat translucent
    // block. BarAreaData.gradient is a LineChart-area property, distinct
    // from (and unaffected by) the PieChartSectionData.gradient
    // version gap documented on the donut chart — see file header.
    lineBarsData.add(
      LineChartBarData(
        spots: historicalSpots,
        isCurved: true,
        gradient: const LinearGradient(
          colors: [AppTheme.brandIndigo, AppTheme.velocityEngine],
        ),
        barWidth: 3.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            if (index == safeDaysPassed && _hasDrawnIn) {
              // "Today" marker — a brighter, larger dot. The soft glow
              // halo around it is painted separately, underneath the
              // chart, in the Stack below (fl_chart dot painters can't
              // emit a BoxShadow-style blur themselves).
              return FlDotCirclePainter(
                radius: 6,
                color: AppTheme.brandPurple,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            }
            return FlDotCirclePainter(
              radius: 2.5,
              color: AppTheme.velocityEngine.withValues(alpha: 0.55),
              strokeWidth: 0,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.velocityEngine.withValues(alpha: 0.32),
              AppTheme.velocityEngine.withValues(alpha: 0.02),
            ],
          ),
        ),
      ),
    );

    // 2. Projection line (dashed) — ONLY if there are enough points.
    // Explicit `List<FlSpot>` type + explicit `<FlSpot>[]` empty literal
    // carried forward unchanged — without these the ternary infers
    // `List<dynamic>`, which fails to satisfy `LineChartBarData.spots`'s
    // `List<FlSpot>` requirement. See file header.
    final List<FlSpot> projectionSpots = safeDaysPassed < spots.length - 2
        ? spots.sublist(safeDaysPassed + 1)
        : <FlSpot>[];

    if (_hasDrawnIn && projectionSpots.isNotEmpty && projectionSpots.length >= 2) {
      lineBarsData.add(
        LineChartBarData(
          spots: projectionSpots,
          isCurved: true,
          color: AppTheme.warning.withValues(alpha: 0.65),
          barWidth: 2,
          isStrokeCapRound: true,
          dashArray: const [5, 5],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.warning.withValues(alpha: 0.10),
                AppTheme.warning.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Soft glow halo behind the "today" marker — painted as a plain
        // positioned blurred circle rather than via fl_chart's dot
        // painter (which has no blur/shadow support), same "adapt the
        // glow vocabulary to the canvas" approach as the donut chart's
        // drop-shadow puck.
        if (_hasDrawnIn)
          Positioned.fill(
            child: IgnorePointer(
              child: _TodayGlowMarker(
                spot: realHistoricalSpots.last,
                maxY: maxY,
                totalX: 29,
              ),
            ),
          ),
        LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: math.max(maxY / 4, 1),
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: AppTheme.borderColor.withValues(alpha: 0.35),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 5,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                      ),
                    );
                  },
                  reservedSize: 20,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '\$${value.toInt()}',
                        style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                      ),
                    );
                  },
                  reservedSize: 35,
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor, width: 1),
                left: BorderSide(color: AppTheme.borderColor, width: 1),
                right: BorderSide.none,
                top: BorderSide.none,
              ),
            ),
            lineBarsData: lineBarsData,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) => AppTheme.textPrimary,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '\$${spot.y.toStringAsFixed(0)}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Today-marker glow — a blurred circle positioned at the historical
// line's last point, roughly approximating fl_chart's own coordinate
// mapping (chart padding + reserved axis space) closely enough to sit
// convincingly under the real dot painted by FlDotData above. Purely
// decorative depth, not pixel-exact — if the chart's reserved sizes
// change, nudge the offsets below to match.
// ============================================================================
class _TodayGlowMarker extends StatelessWidget {
  const _TodayGlowMarker({
    required this.spot,
    required this.maxY,
    required this.totalX,
  });

  final FlSpot spot;
  final double maxY;
  final double totalX;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const leftReserved = 35.0;
        const bottomReserved = 24.0;
        final plotWidth = constraints.maxWidth - leftReserved;
        final plotHeight = constraints.maxHeight - bottomReserved;

        final xFrac = totalX > 0 ? (spot.x / totalX) : 0.0;
        final yFrac = maxY > 0 ? (spot.y / maxY) : 0.0;

        final dx = leftReserved + plotWidth * xFrac;
        final dy = plotHeight - (plotHeight * yFrac);

        return Stack(
          children: [
            Positioned(
              left: dx - 16,
              top: dy - 16,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandPurple.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}