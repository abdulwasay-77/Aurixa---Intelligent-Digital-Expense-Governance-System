/// Recommendation Summary — Phase 7 UI Enhancement (FIXED)
///
/// === FIXES IN THIS VERSION ===
/// 1. `!semantics.parentDataDirty` assertion storm: `_StatTile` previously
///    did `HoverEntrance(child: Expanded(...))`. `HoverEntrance` drives an
///    `AnimatedBuilder` every frame; with `Expanded` directly inside that
///    animated subtree, Flutter re-resolves flex parentData mid-layout
///    during an unfinished semantics pass, causing the assertion storm.
///    Fixed by flipping the nesting: `Expanded(child: HoverEntrance(...))`.
/// 2. Zoom too aggressive: stat tiles sit in a dense 5-across row, not truly
///    isolated, so `HoverSize.large` is changed to `HoverSize.subtle`.
///
/// Hover classification:
///   • Stat tiles — 5-across dense row, no real isolation → HoverSize.subtle
///     (FIXED, was .large).
///   • Savings impact comparison section (Current → Projected → Savings) —
///     wide banner that fills width → HoverGlow with scaleEnabled:false.
///
/// This widget is the summary strip shown ABOVE the filter bar. It contains
/// two rows:
///   1. Five compact stat tiles (Total, Pending, Applied, Monthly Save,
///      Yearly Save) — individually hoverable with HoverSize.subtle.
///   2. A savings-impact comparison row (Current Spend vs Projected vs Delta)
///      — wide banner, scaleEnabled:false.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/recommendation_models.dart';

class RecommendationSummary extends StatelessWidget {
  const RecommendationSummary({
    super.key,
    this.summary,
    this.savingsImpact,
  });

  final RecommendationSummaryResponse? summary;
  final SavingsImpactResponse? savingsImpact;

  @override
  Widget build(BuildContext context) {
    // Null-guard: render nothing before data arrives.
    // The parent (RecommendationsScreen) already guards the summary section,
    // but we guard again here as defence.
    if (summary == null && savingsImpact == null) return const SizedBox.shrink();

    final total = summary?.totalRecommendations ?? 0;
    final pending = summary?.pendingRecommendations ?? 0;
    final actioned = summary?.actionedRecommendations ?? 0;
    final monthly = savingsImpact?.monthlySavings ?? 0;
    final yearly = savingsImpact?.yearlySavings ?? 0;
    final currentSpend = savingsImpact?.currentMonthlySpend ?? 0;
    final projectedSpend = savingsImpact?.projectedMonthlySpend ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Row 1: 5 compact stat tiles ──────────────────────────────────
        // Each tile: dense 5-across row → HoverSize.subtle (FIX #2).
        // Row inside a Container with width: double.infinity (Lesson 8).
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            children: [
              _StatTile(
                index: 0,
                icon: Icons.lightbulb_rounded,
                label: 'Total',
                value: '$total',
                color: AppTheme.recommendations,
              ),
              const SizedBox(width: 10),
              _StatTile(
                index: 1,
                icon: Icons.hourglass_top_rounded,
                label: 'Pending',
                value: '$pending',
                color: AppTheme.warning,
              ),
              const SizedBox(width: 10),
              _StatTile(
                index: 2,
                icon: Icons.check_circle_rounded,
                label: 'Applied',
                value: '$actioned',
                color: AppTheme.success,
              ),
              const SizedBox(width: 10),
              _StatTile(
                index: 3,
                icon: Icons.savings_rounded,
                label: 'Monthly',
                value: '\$${monthly.toStringAsFixed(0)}',
                color: AppTheme.brandBlue,
                isHighlight: monthly > 0,
              ),
              const SizedBox(width: 10),
              _StatTile(
                index: 4,
                icon: Icons.trending_up_rounded,
                label: 'Yearly',
                value: '\$${yearly.toStringAsFixed(0)}',
                color: AppTheme.success,
                isHighlight: yearly > 0,
              ),
            ],
          ),
        ),

        // ── Row 2: Savings impact comparison — only when savingsImpact loaded
        if (savingsImpact != null && currentSpend > 0) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SavingsImpactBar(
              currentSpend: currentSpend,
              projectedSpend: projectedSpend,
              monthlySavings: monthly,
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// _StatTile — compact stat card in a dense 5-across row.
// Shape: not truly isolated → HoverSize.subtle (FIX #2, was .large).
//
// FIX #1 — `Expanded` is now the OUTER widget, `HoverEntrance` nested
// inside it. Previously reversed (`HoverEntrance(child: Expanded(...))`),
// which caused the `!semantics.parentDataDirty` assertion storm: putting a
// flex child (Expanded) directly inside HoverEntrance's per-frame animated
// subtree caused Flutter to re-resolve flex parentData mid-layout during an
// unfinished semantics pass.
// ============================================================================
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.index,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isHighlight = false,
  });

  final int index;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: HoverEntrance(
        index: index,
        child: HoverCard(
          glowColor: color,
          size: HoverSize.subtle, // FIX #2 — was HoverSize.large
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isHighlight ? color : AppTheme.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _SavingsImpactBar — wide comparison strip.
// Shape: wide, fills screen width → scaleEnabled:false (border+glow only).
// ============================================================================
class _SavingsImpactBar extends StatelessWidget {
  const _SavingsImpactBar({
    required this.currentSpend,
    required this.projectedSpend,
    required this.monthlySavings,
  });

  final double currentSpend;
  final double projectedSpend;
  final double monthlySavings;

  @override
  Widget build(BuildContext context) {
    // Savings percentage
    final pct = currentSpend > 0
        ? ((monthlySavings / currentSpend) * 100).clamp(0, 100)
        : 0.0;

    return HoverGlow(
      glowColor: AppTheme.success,
      scaleEnabled: false, // wide banner → no zoom
      borderRadius: AppTheme.radiusCards,
      backgroundColor: AppTheme.bgSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.compare_arrows_rounded,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                const Text(
                  'SAVINGS IMPACT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                if (pct > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${pct.toStringAsFixed(1)}% savings',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Three-panel comparison: Current → arrow → Projected → delta
            Row(
              children: [
                // Current spend
                Expanded(
                  child: _SpendPanel(
                    label: 'Current / mo',
                    value: '\$${currentSpend.toStringAsFixed(0)}',
                    color: AppTheme.textPrimary,
                    isMuted: false,
                  ),
                ),
                // Arrow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: monthlySavings > 0
                            ? AppTheme.success
                            : AppTheme.textMuted,
                      ),
                      if (monthlySavings > 0)
                        Text(
                          '-\$${monthlySavings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                          ),
                        ),
                    ],
                  ),
                ),
                // Projected spend
                Expanded(
                  child: _SpendPanel(
                    label: 'Projected / mo',
                    value: '\$${projectedSpend.toStringAsFixed(0)}',
                    color: monthlySavings > 0
                        ? AppTheme.success
                        : AppTheme.textPrimary,
                    isMuted: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar showing how much of the current spend can be saved
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  // Background track
                  Container(
                    height: 6,
                    color: AppTheme.borderColor,
                  ),
                  // Filled portion (savings fraction)
                  FractionallySizedBox(
                    widthFactor: (pct / 100).clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.success, AppTheme.brandIndigo],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Panel within the impact bar (simple, no independent hover).
class _SpendPanel extends StatelessWidget {
  const _SpendPanel({
    required this.label,
    required this.value,
    required this.color,
    required this.isMuted,
  });

  final String label;
  final String value;
  final Color color;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.1,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}