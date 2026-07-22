/// Insight Card Widget — AI-Generated Financial Insight
///
/// Fix pass: the previous version grew on hover like every other card
/// (HoverCard default scaleEnabled: true) — fine for a compact stat tile,
/// but this card stacks a header + highlighted primary insight + up to
/// 3 secondary lines, so it's tall and its height varies with API
/// content. Scaling a tall variable-height box 8% in place pushed it
/// past its grid cell and over neighboring cards. Two changes:
///   1. scaleEnabled: false — still gets the border + glow lift on
///      hover, just no zoom. Reads as "hoverable" without breaking
///      layout.
///   2. Tighter geometry — removed the nested padded gradient box
///      (padding inside padding inflated height for no visual gain),
///      capped each secondary line to 2 lines with ellipsis, and capped
///      secondary insights at 2 items instead of 3 so the card's height
///      stays predictable next to whatever sits beside it on the grid.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class InsightCardWidget extends StatelessWidget {
  final InsightsResponse? insights;

  const InsightCardWidget({super.key, this.insights});

  @override
  Widget build(BuildContext context) {
    final primary = insights?.primaryInsight ??
        'Add your first subscription to see personalized financial insights.';
    final secondary = <_InsightLine>[
      if (insights?.budgetInsight != null && insights!.budgetInsight.isNotEmpty)
        _InsightLine(Icons.speed_rounded, insights!.budgetInsight, AppTheme.velocityEngine),
      if (insights?.savingsInsight != null && insights!.savingsInsight.isNotEmpty)
        _InsightLine(Icons.savings_rounded, insights!.savingsInsight, AppTheme.success),
    ].take(2).toList();

    return HoverCard(
      glowColor: AppTheme.behaviorLens,
      padding: const EdgeInsets.all(18),
      scaleEnabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              HoverIconBadge(
                icon: Icons.auto_awesome_rounded,
                glowColor: AppTheme.behaviorLens,
                size: 30,
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Insight',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            primary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            for (final line in secondary)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(line.icon, size: 14, color: line.color),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        line.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InsightLine {
  final IconData icon;
  final String text;
  final Color color;
  const _InsightLine(this.icon, this.text, this.color);
}