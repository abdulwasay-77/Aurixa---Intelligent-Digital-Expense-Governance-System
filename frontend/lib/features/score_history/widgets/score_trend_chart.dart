/// Score Trend Chart Widget — Phase 8 Enhancement
///
/// Replaces the legacy flat LineChart with the full Phase 4/5 simulated-3D
/// treatment. No new dependencies — same "gradients + shadows + touch
/// response" approach used by every chart since Phase 4:
///
///   LINE STYLING (simulated depth):
///   - Avg-score line: brandIndigo → scoreCore gradient stroke (same
///     "two-color gradient stroke" trick used by velocity_chart.dart for
///     the historical line) — confirmed safe: LineChartBarData.gradient
///     is a stroke-level property that predates the fl_chart ^0.68.0
///     pin, unlike PieChartSectionData.gradient which does not (see
///     category_donut_chart.dart). Verified independently per Lesson 6
///     (don't assume a property confirmed on one chart class transfers
///     to another — checked LineChartBarData specifically).
///   - Peak line: success color, dashed, subtle — reads as a ceiling.
///   - Low line: danger color, dashed, subtle — reads as a floor.
///   - All three lines share the dashed-vs-solid vocabulary from
///     velocity_chart.dart (solid = primary, dashed = secondary).
///
///   AREA FILL (3D depth):
///   - The avg line's below-area uses a top-to-bottom gradient
///     (scoreCore at full opacity → transparent) — same BarAreaData
///     .gradient pattern as velocity_chart.dart's historical area.
///     BarAreaData.gradient is a LineChart-area property, distinct from
///     the PieChartSectionData.gradient version gap, and confirmed
///     available on the pinned constraint.
///
///   DRAW-IN:
///   - All three series render at y: 0 on the first frame, then swap to
///     real values. LineChart animates data swaps by default — same
///     "render at zero, swap on next frame" technique as velocity_chart
///     and the donut/bar charts.
///
///   TODAY / LATEST DOT GLOW:
///   - The last point on the avg line gets a "today-marker" glow: a
///     slightly larger FlDotCirclePainter + a separate _ScoreGlowMarker
///     widget overlaid via Stack — same glow-puck approach as
///     _TodayGlowMarker in velocity_chart.dart (fl_chart dot painters
///     can't emit a BoxShadow-style blur themselves; the puck is a
///     positioned, blurred Container sitting underneath the chart).
///
///   TOUCH TOOLTIP:
///   - getTooltipColor confirmed correct for the pinned ^0.68.0 version
///     (tooltipBgColor removed by 0.67.0; see monthly_bar_chart.dart
///     for the original version-safety note).
///
///   HOVER TIER:
///   - HoverCard(size: HoverSize.subtle) — wide card hosting an
///     interactive chart. Same classification as every chart card in
///     Phases 4/5: enough zoom to feel alive without fighting fl_chart's
///     own internal touch/tooltip response.
///
///   TOKEN REMAP:
///   - AppTheme.primary → AppTheme.scoreCore (the scoreCore module
///     accent is the semantically correct color here — same as every
///     module using its own accent for chart lines).
///   - AppTheme.bgCanvas → AppTheme.bgBase (no longer referenced here
///     but noted for completeness — legacy ref was in the old Card's
///     bgCanvas background).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class ScoreTrendChart extends StatefulWidget {
  final ScoreTrendResponse? trend;

  const ScoreTrendChart({super.key, this.trend});

  @override
  State<ScoreTrendChart> createState() => _ScoreTrendChartState();
}

class _ScoreTrendChartState extends State<ScoreTrendChart> {
  // Draw-in — same "false → true on first post-frame" pattern as every
  // chart since Phase 4. First frame renders all series at y: 0, then
  // the setState swaps to real values and LineChart's default swap
  // animation grows the curves upward.
  bool _hasDrawnIn = false;

  // Touch state for tooltip + dot highlight
  int _touchedPointIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hasDrawnIn = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.trend?.trend ?? [];
    final improvement = widget.trend?.improvement;

    return HoverCard(
      // Wide chart card — subtle tier so the zoom doesn't fight the
      // chart's own internal hover/touch response (same as every Phase
      // 4/5 chart card).
      glowColor: AppTheme.scoreCore,
      size: HoverSize.subtle,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '6-Month Score Trend',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (improvement != null) _buildImprovementBadge(improvement),
            ],
          ),
          const SizedBox(height: 18),

          // ── Chart ────────────────────────────────────────────────────
          SizedBox(
            height: 230,
            child: points.length < 2
                ? _buildEmptyState()
                : _buildChart(points),
          ),

          // ── Legend ───────────────────────────────────────────────────
          if (points.length >= 2) ...[
            const SizedBox(height: 14),
            _buildLegend(),
          ],
        ],
      ),
    );
  }

  // ── Improvement badge ────────────────────────────────────────────────────

  Widget _buildImprovementBadge(double improvement) {
    final isPositive = improvement >= 0;
    final color = isPositive ? AppTheme.success : AppTheme.danger;
    final icon =
        isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusBadges),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${improvement >= 0 ? '+' : ''}${improvement.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Chart ────────────────────────────────────────────────────────────────

  Widget _buildChart(List<ScoreTrendPoint> points) {
    // Build spot lists — draw-in: y: 0 until _hasDrawnIn
    final avgSpots = List.generate(points.length, (i) {
      return FlSpot(i.toDouble(), _hasDrawnIn ? points[i].avgScore : 0.0);
    });
    final peakSpots = List.generate(points.length, (i) {
      return FlSpot(i.toDouble(), _hasDrawnIn ? points[i].peakScore : 0.0);
    });
    final lowSpots = List.generate(points.length, (i) {
      return FlSpot(i.toDouble(), _hasDrawnIn ? points[i].lowScore : 0.0);
    });

    // Dynamic Y ceiling — include peaks; ensure at least 100
    final maxY = math.max(
      [...avgSpots, ...peakSpots]
          .fold<double>(0, (m, s) => s.y > m ? s.y : m) +
          12,
      100.0,
    );

    // Index of the latest avg point, for the glow marker
    final lastIndex = points.length - 1;
    final lastAvgSpot = avgSpots[lastIndex];

    return Stack(
      children: [
        // ── Glow puck behind the last avg-line point ──────────────────
        // Same architecture as _TodayGlowMarker in velocity_chart.dart:
        // a positioned blurred Container that sits under the chart,
        // roughly approximating fl_chart's coordinate mapping. fl_chart
        // dot painters cannot emit a BoxShadow-style blur directly.
        if (_hasDrawnIn)
          Positioned.fill(
            child: IgnorePointer(
              child: _ScoreGlowMarker(
                spot: lastAvgSpot,
                maxY: maxY,
                totalX: (points.length - 1).toDouble(),
              ),
            ),
          ),

        // ── LineChart ─────────────────────────────────────────────────
        LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,

            // Grid — horizontal lines only, same style as velocity chart
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppTheme.borderColor.withValues(alpha: 0.35),
                strokeWidth: 1,
              ),
            ),

            // Axis titles
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 26,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }
                    final isTouched = index == _touchedPointIndex;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        points[index].monthLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isTouched
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isTouched
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),

            // Border — bottom + left only, same as velocity chart
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor, width: 1),
                left: BorderSide(color: AppTheme.borderColor, width: 1),
                right: BorderSide.none,
                top: BorderSide.none,
              ),
            ),

            // ── Series (back → front: low, peak, avg) ─────────────────
            lineBarsData: [
              // 1. Low score — dashed red, very subtle
              LineChartBarData(
                spots: lowSpots,
                isCurved: true,
                color: AppTheme.danger.withValues(alpha: 0.40),
                barWidth: 1.5,
                isStrokeCapRound: true,
                dashArray: const [4, 5],
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),

              // 2. Peak score — dashed green, subtle ceiling
              LineChartBarData(
                spots: peakSpots,
                isCurved: true,
                color: AppTheme.success.withValues(alpha: 0.40),
                barWidth: 1.5,
                isStrokeCapRound: true,
                dashArray: const [4, 5],
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),

              // 3. Avg score — primary line, gradient stroke + gradient
              //    area fill + per-dot painters + glow on the last dot.
              //
              //    LineChartBarData.gradient (stroke gradient) is
              //    confirmed safe on the pinned ^0.68.0 constraint —
              //    checked independently per Lesson 6, same verification
              //    as velocity_chart.dart's historical line gradient.
              //    BarAreaData.gradient (area fill) also confirmed.
              LineChartBarData(
                spots: avgSpots,
                isCurved: true,
                // Gradient stroke: brandIndigo → scoreCore — same
                // two-color stroke gradient as velocity chart's
                // historical line (brandIndigo → velocityEngine).
                gradient: const LinearGradient(
                  colors: [AppTheme.brandIndigo, AppTheme.scoreCore],
                ),
                barWidth: 3.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    final isLast = index == lastIndex;
                    if (isLast && _hasDrawnIn) {
                      // Latest-point marker — same "today dot" style as
                      // velocity_chart.dart: larger radius, white stroke,
                      // scoreCore fill. The glow bloom around it is the
                      // _ScoreGlowMarker Stack layer above.
                      return FlDotCirclePainter(
                        radius: 6,
                        color: AppTheme.scoreCore,
                        strokeWidth: 2.5,
                        strokeColor: Colors.white,
                      );
                    }
                    final isTouched = index == _touchedPointIndex;
                    return FlDotCirclePainter(
                      radius: isTouched ? 5 : 3,
                      color: isTouched
                          ? AppTheme.scoreCore
                          : AppTheme.brandIndigo.withValues(alpha: 0.55),
                      strokeWidth: isTouched ? 2 : 0,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                // Gradient area fill — same top-to-bottom gradient as
                // velocity_chart.dart's historical area: score color at
                // the top, transparent at the base. Confirmed safe on
                // LineChart's BarAreaData (distinct from the pie
                // gradient gap documented in category_donut_chart.dart).
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.scoreCore.withValues(alpha: 0.28),
                      AppTheme.scoreCore.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ],

            // Touch tooltip — getTooltipColor (not the removed
            // tooltipBgColor) per the version-safety note carried
            // through from monthly_bar_chart.dart.
            lineTouchData: LineTouchData(
              enabled: true,
              touchCallback: (event, response) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      response == null ||
                      response.lineBarSpots == null ||
                      response.lineBarSpots!.isEmpty) {
                    _touchedPointIndex = -1;
                    return;
                  }
                  // All three series share the same x-axis; report the
                  // x index of whichever bar was touched.
                  _touchedPointIndex =
                      response.lineBarSpots!.first.x.toInt();
                });
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppTheme.textPrimary,
                getTooltipItems: (touchedSpots) {
                  const labels = ['Low', 'Peak', 'Avg'];
                  return touchedSpots.map((spot) {
                    final labelText = spot.barIndex < labels.length
                        ? labels[spot.barIndex]
                        : 'Score';
                    return LineTooltipItem(
                      '$labelText: ${spot.y.toStringAsFixed(0)}',
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

  // ── Legend ───────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Row(
      children: [
        _LegendDot(
          color: AppTheme.scoreCore,
          label: 'Avg Score',
          solid: true,
        ),
        const SizedBox(width: 16),
        _LegendDot(
          color: AppTheme.success.withValues(alpha: 0.65),
          label: 'Peak',
          solid: false,
        ),
        const SizedBox(width: 16),
        _LegendDot(
          color: AppTheme.danger.withValues(alpha: 0.65),
          label: 'Low',
          solid: false,
        ),
      ],
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.scoreCore.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              size: 28,
              color: AppTheme.scoreCore,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Not enough score history yet',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scores appear here once calculated for 2+ months',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _LegendDot — small legend row item (solid dot or dashed line swatch).
// ============================================================================

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool solid;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.solid,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (solid)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 5,
                ),
              ],
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 5, height: 2, color: color),
              const SizedBox(width: 2),
              Container(width: 5, height: 2, color: color),
            ],
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _ScoreGlowMarker
//
// Mirrors _TodayGlowMarker from velocity_chart.dart exactly — a blurred
// circle positioned at the last avg-line point, sitting underneath the
// chart in a Stack. fl_chart dot painters cannot emit BoxShadow-style
// blurs; this is the canonical "glow puck" workaround used since Phase 5.
//
// Coordinate approximation: leftReserved + bottomReserved must match the
// SideTitles.reservedSize values set in the FlTitlesData above (32 left,
// 26 bottom). If those change, nudge these to match.
// ============================================================================

class _ScoreGlowMarker extends StatelessWidget {
  final FlSpot spot;
  final double maxY;
  final double totalX;

  const _ScoreGlowMarker({
    required this.spot,
    required this.maxY,
    required this.totalX,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const leftReserved = 32.0;
        const bottomReserved = 26.0;
        final plotWidth = constraints.maxWidth - leftReserved;
        final plotHeight = constraints.maxHeight - bottomReserved;

        final xFrac = totalX > 0 ? (spot.x / totalX) : 0.0;
        final yFrac = maxY > 0 ? (spot.y / maxY) : 0.0;

        final dx = leftReserved + plotWidth * xFrac;
        final dy = plotHeight - (plotHeight * yFrac);

        return Stack(
          children: [
            Positioned(
              left: dx - 18,
              top: dy - 18,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.scoreCore.withValues(alpha: 0.50),
                      blurRadius: 22,
                      spreadRadius: 2,
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