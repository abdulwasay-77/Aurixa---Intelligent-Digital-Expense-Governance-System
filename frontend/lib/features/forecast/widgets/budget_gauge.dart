/// Budget Gauge Widget — Shows spending progress with animated gauge
///
/// Phase 5 — VelocityEngine visual overhaul:
///   - Rebuilt on HoverCard (module accent = AppTheme.velocityEngine)
///     instead of a plain Material Card.
///   - Shape correction: originally given HoverSize.large on the theory
///     that two big numbers + a bar reads as compact/isolated. In
///     practice the card is wide and content-dense (status badge row,
///     two-number row, full-width progress track, two-label row, all
///     stacked tightly) -- closer to the BehaviorLens chart cards than
///     to an isolated stat tile, and the 1.08x zoom was pushing it past
///     its grid cell. Moved to HoverSize.subtle, matching every other
///     dense card in this phase (VelocityChart, ForecastSummary's outer
///     card) -- picking an existing named tier rather than a one-off
///     scaleOverride, per the standing rule.
///   - The flat LinearProgressIndicator is replaced with a custom
///     gradient-filled track (TweenAnimationBuilder driving the fill
///     width) so the bar itself carries the brand gradient when on
///     track, and shifts to a solid warning/danger gradient as risk
///     rises — same "module default, status override" rule used for
///     hover glow, applied here to the progress fill.
///   - Breach state gets a slow pulsing glow on the status badge (not a
///     hover-triggered glow — this one runs continuously to read as an
///     active alert) using a repeating AnimationController, fully
///     separate from the HoverCard's own hover-driven Transform per the
///     locked "entrance/hover never share a Transform" rule — this is a
///     third, independent animation layer (continuous status pulse),
///     not entrance and not hover, so it gets its own AnimatedBuilder
///     rather than borrowing either of theirs.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class BudgetGauge extends StatefulWidget {
  final CurrentMonthForecast? forecast;

  const BudgetGauge({super.key, this.forecast});

  @override
  State<BudgetGauge> createState() => _BudgetGaugeState();
}

class _BudgetGaugeState extends State<BudgetGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  // Draw-in: progress fill animates from 0 to its real percentage on
  // first build via TweenAnimationBuilder below — distinct technique
  // from the fl_chart-driven draw-ins on BehaviorLens, since this is a
  // plain Flutter widget with no chart library underneath it (same
  // category as the spending heatmap's width tween).
  bool _hasDrawnIn = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hasDrawnIn = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spent = widget.forecast?.spentSoFar ?? 0;
    final budget = widget.forecast?.budgetLimit ?? 1;
    final percentage = (spent / budget).clamp(0.0, 1.0);
    final isBreached = spent > budget;
    final status = widget.forecast?.status ?? 'ON_TRACK';
    final remaining = (budget - spent).clamp(0, double.infinity);

    final statusColors = _colorsFor(status);

    return HoverCard(
      glowColor: AppTheme.velocityEngine,
      size: HoverSize.subtle,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Budget Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              _StatusBadge(
                status: status,
                colors: statusColors,
                pulse: isBreached,
                pulseController: _pulseController,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${spent.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Text(
                    'Spent so far',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${budget.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Text(
                    'Monthly Budget',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _GradientProgressTrack(
            targetPercentage: _hasDrawnIn ? percentage : 0.0,
            colors: statusColors,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(percentage * 100).toInt()}% used',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isBreached ? AppTheme.danger : AppTheme.textSecondary,
                ),
              ),
              Text(
                isBreached
                    ? '⚠️ \$${(spent - budget).toStringAsFixed(0)} over'
                    : '\$${remaining.toStringAsFixed(0)} remaining',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isBreached ? AppTheme.danger : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Module default (brand gradient, "on track") with status override —
  // same rule HoverGlowColors codifies for hover glow, applied here to
  // the progress fill gradient.
  List<Color> _colorsFor(String status) {
    switch (status) {
      case 'BREACHED':
        return [AppTheme.danger, Color.lerp(AppTheme.danger, Colors.black, 0.15)!];
      case 'AT_RISK':
        return [AppTheme.warning, Color.lerp(AppTheme.warning, Colors.black, 0.1)!];
      case 'UNDER_BUDGET':
        return [AppTheme.success, Color.lerp(AppTheme.success, Colors.black, 0.1)!];
      default:
        return [AppTheme.brandBlue, AppTheme.brandIndigo];
    }
  }
}

// ============================================================================
// Gradient progress track — replaces the flat LinearProgressIndicator.
// Animates its fill width from 0 to the real percentage on first build,
// and carries a top-edge highlight so the filled portion reads as a
// raised, lit bar rather than a flat color block — same depth
// vocabulary as the BehaviorLens bar chart's per-bar gradient.
// ============================================================================
class _GradientProgressTrack extends StatelessWidget {
  const _GradientProgressTrack({
    required this.targetPercentage,
    required this.colors,
  });

  final double targetPercentage;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 14,
        color: AppTheme.bgElevated,
        child: Stack(
          children: [
            // Faint tinted groove so even a 0% bar has a visible boundary
            // against the card surface (same lesson as the heatmap's
            // contrast-floor fix).
            Container(color: AppTheme.bgBase.withValues(alpha: 0.18)),
            LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: targetPercentage,
                  heightFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(colors.first, Colors.white, 0.35)!,
                          colors.last,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.first.withValues(alpha: 0.45),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Status badge — adds a slow continuous pulse glow when breached. This
// is a third animation layer (neither entrance nor hover): it owns its
// own AnimationController, driven by the parent, so it never touches the
// Transform that HoverCard's hover-scale uses.
// ============================================================================
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.colors,
    required this.pulse,
    required this.pulseController,
  });

  final String status;
  final List<Color> colors;
  final bool pulse;
  final AnimationController pulseController;

  String get _label {
    switch (status) {
      case 'BREACHED':
        return 'BREACHED';
      case 'AT_RISK':
        return 'AT RISK';
      case 'UNDER_BUDGET':
        return 'UNDER BUDGET';
      default:
        return 'ON TRACK';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!pulse) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: colors.first.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.first,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final t = pulseController.value; // 0 -> 1 -> 0, repeat(reverse: true)
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: colors.first.withValues(alpha: 0.15 + 0.10 * t),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.25 + 0.30 * t),
                blurRadius: 6 + 10 * t,
                spreadRadius: 0.5 * t,
              ),
            ],
          ),
          child: Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.first,
              letterSpacing: 0.3,
            ),
          ),
        );
      },
    );
  }
}