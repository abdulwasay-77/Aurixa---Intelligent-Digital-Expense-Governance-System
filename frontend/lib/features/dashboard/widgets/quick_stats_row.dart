/// Quick Stats Row — Phase 2 addition.
///
/// A compact strip of four small stat tiles sitting directly under the
/// hero header. Surfaces data the dashboard was already fetching
/// (active subscription count, monthly spend, days-to-breach, unread
/// alerts) but never actually showed at a glance before — previously you
/// had to read into the Score/Velocity/Alerts cards individually to piece
/// this together. Each tile is a HoverIconBadge-style small card (small
/// hover size, punchier zoom per spec) with its own module accent color.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class QuickStatsRow extends StatelessWidget {
  const QuickStatsRow({
    super.key,
    required this.activeSubscriptions,
    required this.monthlySpend,
    required this.forecast,
    required this.alertSummary,
  });

  final int activeSubscriptions;
  final int monthlySpend;
  final CurrentMonthForecast? forecast;
  final AlertSummaryResponse? alertSummary;

  @override
  Widget build(BuildContext context) {
    final daysToBreach = forecast?.daysToBreach;
    final unreadAlerts = alertSummary?.unreadAlerts ?? 0;
    final dailyAllowance = forecast?.dailyAllowance;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final tiles = [
          _StatTile(
            icon: Icons.subscriptions_rounded,
            label: 'Active Subscriptions',
            value: '$activeSubscriptions',
            accent: AppTheme.subVault,
          ),
          _StatTile(
            icon: Icons.payments_rounded,
            label: 'Monthly Spend',
            value: '\$$monthlySpend',
            accent: AppTheme.velocityEngine,
          ),
          _StatTile(
            icon: Icons.bolt_rounded,
            label: 'Daily Allowance',
            value: dailyAllowance != null
                ? '\$${dailyAllowance.toStringAsFixed(0)}'
                : '—',
            accent: AppTheme.brandPurple,
          ),
          _StatTile(
            icon: unreadAlerts > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            label: unreadAlerts > 0 ? 'Unread Alerts' : 'Alerts',
            value: '$unreadAlerts',
            accent: unreadAlerts > 0 ? AppTheme.danger : AppTheme.riskRadar,
            subtitle: daysToBreach != null && daysToBreach > 0
                ? '$daysToBreach days to breach'
                : null,
          ),
        ];

        if (isNarrow) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: tiles
                .map((t) => SizedBox(
                      width: (constraints.maxWidth - 16) / 2,
                      child: t,
                    ))
                .toList(),
          );
        }

        return Row(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      glowColor: accent,
      size: HoverSize.small,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle ?? label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: subtitle != null
                        ? AppTheme.warning
                        : AppTheme.textMuted,
                    fontWeight: subtitle != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}