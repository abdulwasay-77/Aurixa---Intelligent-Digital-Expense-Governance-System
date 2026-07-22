/// Sub-Score Bars Widget — Phase 8 Enhancement
///
/// Replaces the legacy flat LinearProgressIndicator rows with the full
/// Nebula treatment:
///
///   SHAPE CLASSIFICATION:
///   - Each sub-score row is a compact, well-spaced item inside a card
///     — but there are 4 of them stacked vertically in a single card, so
///     the outer card is tall/dense → outer HoverCard: scaleEnabled: false
///     (glow-only). The INDIVIDUAL row items are isolated enough when
///     they have breathing room between them → HoverCard(size:
///     HoverSize.subtle) per row. This matches the Lesson 2 principle:
///     judge layout density, not element size.
///
///   SIMULATED 3D ON PROGRESS BARS:
///   - Each progress bar uses a Stack of two ClipRRect + Container
///     layers: a background track with a subtle inset shadow (simulates
///     a recessed groove) and a filled progress layer with a two-stop
///     left-to-right gradient (lighter at the left edge, full color
///     toward the right) — same "lit column" vocabulary as the bar
///     chart's barWidth gradient, adapted to a horizontal bar.
///   - A thin highlight strip is pinned to the top of each filled bar
///     (a narrow, semi-transparent white Container inside the Stack) —
///     the same top-surface highlight used by the bar chart's
///     top-to-bottom gradient, now expressed as a literal thin strip
///     since horizontal gradients can't produce it without a second axis.
///   - Each row's icon badge has a glow that matches its sub-score color
///     (BoxShadow on the icon container) — same glow vocabulary as the
///     donut legend dots.
///
///   DRAW-IN ANIMATION:
///   - Each _SubScoreRow is a StatefulWidget that animates its own
///     progress bar from 0 → real value (Tween<double> + AnimationController,
///     staggered by an `index` parameter × 120 ms) — own lifecycle per
///     row (Lesson 7: each controller in its own StatefulWidget, not
///     in the parent). RepaintBoundary wraps each row so per-frame bar
///     paints don't dirty the siblings.
///
///   TOKEN REMAP:
///   - AppTheme.violet (old alias for brandIndigo) replaced with
///     AppTheme.brandIndigo directly in the subscriptionDependency row.
///   - AppTheme.primary replaced with AppTheme.scoreCore for any blue
///     tints that were semantic "module color" not accent-blue.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class SubScoreBars extends StatelessWidget {
  final FinancialScoreResponse? score;

  const SubScoreBars({super.key, this.score});

  @override
  Widget build(BuildContext context) {
    final items = [
      _SubScoreItem(
        label: 'Savings Rate',
        description: 'How much of your income you keep',
        value: score?.savingsRateScore,
        color: AppTheme.success,
        icon: Icons.savings_rounded,
      ),
      _SubScoreItem(
        label: 'Budget Discipline',
        description: 'How well you stick to your budget',
        // scoreCore replaces old AppTheme.primary reference
        value: score?.budgetDisciplineScore,
        color: AppTheme.scoreCore,
        icon: Icons.rule_rounded,
      ),
      _SubScoreItem(
        label: 'Subscription Dependency',
        description: 'Share of spend locked into subscriptions',
        value: score?.subDependencyRatio,
        // brandIndigo directly replaces AppTheme.violet alias
        color: AppTheme.brandIndigo,
        icon: Icons.subscriptions_rounded,
      ),
      _SubScoreItem(
        label: 'Risk Factor',
        description: 'Exposure to anomalies and budget breaches',
        value: score?.riskFactorScore,
        color: AppTheme.warning,
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return HoverCard(
      glowColor: AppTheme.scoreCore,
      // Outer card is tall (4 rows + header) → glow-only, no zoom.
      scaleEnabled: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.scoreCore.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  size: 16,
                  color: AppTheme.scoreCore,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Score Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Sub-score rows ────────────────────────────────────────────
          ...items.asMap().entries.map((entry) {
            return Padding(
              // Breathing room between rows — this spacing is what makes
              // HoverSize.subtle (not large) the right tier per item.
              padding: EdgeInsets.only(
                bottom: entry.key < items.length - 1 ? 12 : 0,
              ),
              child: RepaintBoundary(
                // Lesson 7 — RepaintBoundary around each animated row so
                // its per-frame progress-bar paints don't invalidate the
                // other rows or the header.
                child: _SubScoreRow(
                  item: entry.value,
                  index: entry.key,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================================
// _SubScoreRow
//
// Self-contained StatefulWidget per row. Owns its own AnimationController
// for the progress-bar draw-in (Lesson 7). Staggered by index × 120 ms
// so rows cascade in from top to bottom after the card's entrance.
//
// Shape: individual row inside a tall card. The row itself is compact
// and well-spaced → HoverSize.subtle (not large — the enclosing card is
// dense enough to make "large" feel aggressive).
// ============================================================================

class _SubScoreRow extends StatefulWidget {
  final _SubScoreItem item;
  final int index;

  const _SubScoreRow({super.key, required this.item, required this.index});

  @override
  State<_SubScoreRow> createState() => _SubScoreRowState();
}

class _SubScoreRowState extends State<_SubScoreRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    final hasValue = widget.item.value != null;
    final targetValue =
        hasValue ? (widget.item.value!.clamp(0.0, 100.0) / 100.0) : 0.0;

    _progressAnim = Tween<double>(begin: 0.0, end: targetValue).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    // Stagger: each row waits index × 120 ms before starting its draw-in.
    Future.delayed(
      Duration(milliseconds: 120 * widget.index),
      () {
        if (mounted) _ctrl.forward();
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasValue = item.value != null;
    final displayValue =
        hasValue ? item.value!.clamp(0.0, 100.0) : 0.0;

    return HoverCard(
      glowColor: HoverGlowColors.forModuleAndStatus(
        moduleColor: item.color,
      ),
      size: HoverSize.subtle,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row header: icon + labels + score number ──────────────────
          Row(
            children: [
              // Icon badge with color glow — same vocabulary as the
              // donut legend dots (BoxShadow on the icon container).
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.28),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(item.icon, size: 18, color: item.color),
              ),
              const SizedBox(width: 12),

              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Score number — animated counter driven by _progressAnim
              AnimatedBuilder(
                animation: _progressAnim,
                builder: (context, _) {
                  final animatedScore = _progressAnim.value * 100;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasValue
                            ? animatedScore.toInt().toString()
                            : '—',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: hasValue ? item.color : AppTheme.textMuted,
                          height: 1,
                        ),
                      ),
                      Text(
                        hasValue ? 'pts' : '',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: item.color.withValues(alpha: 0.60),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Simulated-3D progress bar ─────────────────────────────────
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (context, _) {
              return _3DProgressBar(
                progress: _progressAnim.value,
                color: item.color,
                hasValue: hasValue,
              );
            },
          ),

          // ── Tier label below the bar ──────────────────────────────────
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.textMuted,
                ),
              ),
              Text(
                _tierLabel(displayValue, hasValue),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: hasValue ? item.color : AppTheme.textMuted,
                ),
              ),
              Text(
                '100',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _tierLabel(double value, bool hasValue) {
    if (!hasValue) return 'No data';
    if (value >= 80) return 'Excellent';
    if (value >= 60) return 'Good';
    if (value >= 40) return 'Fair';
    return 'Needs Work';
  }
}

// ============================================================================
// _3DProgressBar
//
// Simulated-3D horizontal progress bar using a Stack of three layers:
//
//   1. Background track — slight inset-shadow effect (dark bottom border)
//      to simulate a recessed groove (same "grooved track" vocabulary as
//      the bar chart's backDrawRodData gradient which shades top→bottom
//      to look like a hollow).
//
//   2. Filled progress area — left-to-right two-stop gradient:
//      lighter tint at the left edge (light source), full color toward
//      the right. Equivalent to the bar chart's top-to-bottom gradient
//      that makes each bar look like a lit, rounded column, rotated 90°
//      for horizontal context.
//
//   3. Thin highlight strip at the top of the filled area — a narrow
//      semi-transparent white bar pinned to the top, simulating the
//      specular highlight that would catch on a rounded surface. The bar
//      chart achieves this implicitly through the gradient's top stop
//      (Color.lerp toward white); for a horizontal bar it's cleaner as
//      an explicit thin strip.
// ============================================================================

class _3DProgressBar extends StatelessWidget {
  final double progress; // 0.0 → 1.0
  final Color color;
  final bool hasValue;

  const _3DProgressBar({
    required this.progress,
    required this.color,
    required this.hasValue,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = color;
    final lightColor = Color.lerp(fillColor, Colors.white, 0.30)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          // Layer 1 — background track (recessed groove)
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.bgElevated,
                  AppTheme.bgBase.withValues(alpha: 0.30),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.borderColor.withValues(alpha: 0.60),
                width: 0.5,
              ),
            ),
          ),

          // Layer 2 — filled progress area with lit gradient
          if (hasValue && progress > 0)
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    // Left-to-right: light edge → full color — the
                    // horizontal equivalent of the bar chart's
                    // top-to-bottom lit-column gradient.
                    colors: [lightColor, fillColor],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

          // Layer 3 — thin specular highlight strip at top of fill
          // Only visible over the filled portion; clipped by the
          // FractionallySizedBox so it ends where the fill ends.
          if (hasValue && progress > 0)
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 3, // top-pinned thin strip
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.45),
                      Colors.white.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// _SubScoreItem — plain data holder (unchanged from legacy, just
// consolidated here instead of in a separate part file).
// ============================================================================

class _SubScoreItem {
  final String label;
  final String description;
  final double? value;
  final Color color;
  final IconData icon;

  const _SubScoreItem({
    required this.label,
    required this.description,
    required this.value,
    required this.color,
    required this.icon,
  });
}