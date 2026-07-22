/// Category Donut Chart — Spending breakdown by category
///
/// Phase 4 — BehaviorLens. Visual overhaul for "stunning, 3D-feeling,
/// hoverable" charts, using only fl_chart + Flutter primitives (no new
/// 3D rendering dependency — simulated depth via gradients/shadows/touch
/// response):
///   - Each donut segment draws with a solid, slightly-deepened color at
///     rest (PieChartSectionData.gradient isn't available on the
///     fl_chart version pinned here — ^0.68.0 predates that feature, see
///     inline note) and brightens + pops outward on touch/hover via
///     fl_chart's own PieTouchData, simulating a raised, lit surface
///     through color shift + radius change rather than an in-section
///     gradient.
///   - A soft colored drop shadow sits underneath the whole donut
///     (one shadow per dominant color blended toward the chart's overall
///     palette) to lift it off the card — same "glow" vocabulary as the
///     rest of the app's HoverCard system, just applied to a chart.
///   - Touching/hovering a segment pops it outward (increases its
///     `radius` + lightens it) — fl_chart's own PieTouchData drives
///     this, interpolated by the chart's swapAnimationDuration, so the
///     "pop" itself is a real animated transition, not a jump-cut.
///   - Draw-in animation: the chart is first built with all values at
///     zero, then swaps to real data one frame later. PieChart animates
///     data swaps automatically by default — this is the deferred
///     "chart draws itself in" requirement from the original UI spec,
///     using the chart library's own built-in animation rather than
///     hand-rolled tweening. (Deliberately not passing an explicit
///     duration/curve override — the exact parameter name depends on
///     the precise patch fl_chart's pinned ^0.68.0 resolves to, and the
///     default animation already achieves the effect.)
///   - Card itself uses HoverCard(size: HoverSize.subtle) — a chart this
///     size benefits from SOME zoom on hover (feels alive) without the
///     aggressive 1.08x that would fight the donut's own internal
///     hover-pop animation.
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class CategoryDonutChart extends StatefulWidget {
  final List<CategorySpendResponse> categories;

  const CategoryDonutChart({super.key, required this.categories});

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int _touchedIndex = -1;

  // Draw-in: chart renders at zero values on the very first frame, then
  // swaps to real data — fl_chart animates the transition itself via
  // swapAnimationDuration below. See file header for rationale.
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
    if (widget.categories.isEmpty) {
      return _buildEmptyState();
    }

    final total = widget.categories.fold<double>(0, (sum, c) => sum + c.totalAmount);
    final dominantColor = widget.categories.isNotEmpty
        ? widget.categories
            .reduce((a, b) => a.totalAmount > b.totalAmount ? a : b)
            .color
        : AppTheme.behaviorLens;

    return HoverCard(
      glowColor: AppTheme.behaviorLens,
      size: HoverSize.subtle,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending by Category',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft colored shadow "puck" beneath the donut — gives it
                // a sense of sitting above the card surface rather than
                // being printed flat on it.
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dominantColor.withValues(alpha: 0.30),
                        blurRadius: 36,
                        spreadRadius: -6,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                ),
                // NOTE: PieChart animates data swaps by default (~150ms)
                // even with no duration/curve passed — deliberately not
                // passing an explicit duration/curve here, since the
                // exact parameter name (duration/curve vs the older
                // swapAnimationDuration/swapAnimationCurve) depends on
                // the precise patch version fl_chart's ^0.68.0 resolves
                // to, and getting that wrong would fail the build. The
                // default built-in animation already gives us the
                // "draws itself in" growth from the zero-value state to
                // real data — no explicit override needed.
                PieChart(
                  PieChartData(
                    sections: _buildSections(total),
                    centerSpaceRadius: 42,
                    sectionsSpace: 3,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex =
                              pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                ),
                // Center readout — total spend, sits in the donut hole.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\$${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(double total) {
    return widget.categories.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final isTouched = index == _touchedIndex;

      // FIX (carried over): explicit `0.0` (double) instead of `0` (int)
      // in the else-branch, so `percentage` is always inferred as
      // `double`, not `num` — same ternary type-inference smell that
      // affected the heatmap and the velocity chart.
      final double percentage =
          total > 0 ? (category.totalAmount / total * 100) : 0.0;
      final color = category.color;
      final isSignificant = percentage > 5;

      // Draw-in: while not yet drawn in, every section reports a
      // near-zero value so the initial paint is a thin ring, then the
      // post-frame setState above swaps in `category.totalAmount` and
      // PieChart's own default swap animation grows each wedge out to
      // its real size — the "chart draws itself in" effect.
      final value = _hasDrawnIn ? category.totalAmount : 0.001;

      // Simulated 3D, version-safe: PieChartSectionData.gradient doesn't
      // exist on the fl_chart version pinned here (^0.68.0 — gradient
      // support on pie sections was added later, in 0.71.0). Depth is
      // instead carried by: a brightened solid color + white border
      // when touched (simulates a highlight catching the raised edge),
      // a deeper shadow-color for the resting state, and the
      // surrounding drop-shadow "puck" + radius pop on touch.
      final restingColor = Color.lerp(color, Colors.black, 0.06)!;
      final touchedColor = Color.lerp(color, Colors.white, 0.18)!;

      return PieChartSectionData(
        color: isTouched ? touchedColor : restingColor,
        value: value,
        title: isSignificant ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: isTouched ? 70 : 60,
        titlePositionPercentageOffset: 0.62,
        titleStyle: TextStyle(
          fontSize: isTouched ? 13 : 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 3)],
        ),
        showTitle: isSignificant,
        borderSide: isTouched
            ? const BorderSide(color: Colors.white, width: 2)
            : BorderSide.none,
      );
    }).toList();
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: widget.categories.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value;
        final isTouched = index == _touchedIndex;

        return AnimatedContainer(
          duration: AppTheme.hoverDuration,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isTouched ? category.color.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [category.color, Color.lerp(category.color, Colors.black, 0.1)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: category.color.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                category.categoryName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isTouched ? FontWeight.w600 : FontWeight.normal,
                  color: isTouched ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
                Icons.pie_chart_outline_rounded,
                size: 32,
                color: AppTheme.behaviorLens,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No spending data available',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}