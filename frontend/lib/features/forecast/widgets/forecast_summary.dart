/// Forecast Summary Widget — Displays key forecast metrics
///
/// Phase 5 — VelocityEngine visual overhaul:
///   - Outer container rebuilt on HoverCard (scaleEnabled: false) — this
///     card mixes a 2x2 stat grid with a variable-length message banner
///     at the bottom, so its overall height isn't fixed; treating it
///     like a tall/text-heavy card (per the shape-first rule) avoids a
///     zoom-in-place pushing the message banner past the card's grid
///     cell. The punch instead lives on the four stat tiles themselves.
///   - Each of the 4 stat tiles (Days Remaining, Projected Total, Daily
///     Allowance, Days to Breach) is now its own HoverIconBadge-style
///     mini tile — compact, isolated, evenly spaced in a grid with
///     breathing room on all sides, so HoverSize.small fits per the
///     shape-first rule (this is the same reasoning that makes icon
///     badges elsewhere in the app punchy, not a borrowed default).
///   - Alert banner gets a colored left accent bar + soft glow matching
///     its status color, instead of a flat tinted box, for consistency
///     with the rest of the Nebula status vocabulary.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class ForecastSummary extends StatelessWidget {
  final CurrentMonthForecast? forecast;

  const ForecastSummary({super.key, this.forecast});

  @override
  Widget build(BuildContext context) {
    final spent = forecast?.spentSoFar ?? 0;
    final budget = forecast?.budgetLimit ?? 1;
    final projected = forecast?.projectedTotal ?? 0;
    final daysToBreach = forecast?.daysToBreach;
    final daysRemaining = forecast?.daysRemaining ?? 0;
    final dailyAllowance = forecast?.dailyAllowance ?? 0;
    final isBreached = spent > budget;
    final alertColor = _alertColor();

    return HoverCard(
      glowColor: AppTheme.velocityEngine,
      scaleEnabled: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forecast Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final tiles = [
                _StatTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'Days Remaining',
                  value: '$daysRemaining',
                  color: daysRemaining <= 5 ? AppTheme.warning : AppTheme.velocityEngine,
                ),
                _StatTile(
                  icon: Icons.trending_up_rounded,
                  label: 'Projected Total',
                  value: '\$${projected.toStringAsFixed(0)}',
                  color: isBreached ? AppTheme.danger : AppTheme.velocityEngine,
                ),
                _StatTile(
                  icon: Icons.attach_money_rounded,
                  label: 'Daily Allowance',
                  value: '\$${dailyAllowance.toStringAsFixed(0)}',
                  color: dailyAllowance < 50 ? AppTheme.warning : AppTheme.velocityEngine,
                ),
                _StatTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'Days to Breach',
                  value: daysToBreach != null ? '${daysToBreach}d' : '—',
                  color: daysToBreach != null && daysToBreach <= 7
                      ? AppTheme.danger
                      : daysToBreach != null && daysToBreach <= 15
                          ? AppTheme.warning
                          : AppTheme.velocityEngine,
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: [
                    Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 10), Expanded(child: tiles[1])]),
                    const SizedBox(height: 10),
                    Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 10), Expanded(child: tiles[3])]),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: tiles[0]),
                  const SizedBox(width: 10),
                  Expanded(child: tiles[1]),
                  const SizedBox(width: 10),
                  Expanded(child: tiles[2]),
                  const SizedBox(width: 10),
                  Expanded(child: tiles[3]),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(AppTheme.radiusInputs),
              border: Border.all(color: alertColor.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: alertColor.withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 34,
                  margin: const EdgeInsets.only(right: 12, top: 1),
                  decoration: BoxDecoration(
                    color: alertColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(_alertIcon(), color: alertColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    forecast?.message ?? 'Loading forecast...',
                    style: TextStyle(
                      fontSize: 13,
                      color: alertColor,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _alertColor() {
    final status = forecast?.status ?? 'ON_TRACK';
    switch (status) {
      case 'BREACHED':
        return AppTheme.danger;
      case 'AT_RISK':
        return AppTheme.warning;
      case 'UNDER_BUDGET':
        return AppTheme.success;
      default:
        return AppTheme.velocityEngine;
    }
  }

  IconData _alertIcon() {
    final status = forecast?.status ?? 'ON_TRACK';
    switch (status) {
      case 'BREACHED':
        return Icons.error_outline_rounded;
      case 'AT_RISK':
        return Icons.warning_amber_rounded;
      case 'UNDER_BUDGET':
        return Icons.thumb_up_alt_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }
}

// ============================================================================
// Stat tile — compact, isolated, evenly-spaced grid cell. HoverSize.small
// fits per the shape-first rule: plenty of breathing room on every side
// inside its Expanded slot, nothing packed tightly against it.
// ============================================================================
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return HoverGlow(
      glowColor: color,
      size: HoverSize.small,
      borderRadius: AppTheme.radiusInputs,
      backgroundColor: AppTheme.bgElevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}