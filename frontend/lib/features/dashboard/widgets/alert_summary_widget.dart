/// Alert Summary Widget — Unread alert counts
/// Phase 2: rebuilt on HoverCard. Glow color follows the locked rule —
/// RiskRadar's module default is danger-red already, but we make the
/// override logic explicit here (escalates to a stronger pulse only when
/// there are unread CRITICAL alerts) so Phase 6 (alerts_screen.dart) has
/// a working reference implementation to extend.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';
import '../../../core/constants/app_constants.dart';

class AlertSummaryWidget extends StatelessWidget {
  final AlertSummaryResponse? alertSummary;

  const AlertSummaryWidget({super.key, this.alertSummary});

  @override
  Widget build(BuildContext context) {
    final total = alertSummary?.totalAlerts ?? 0;
    final unread = alertSummary?.unreadAlerts ?? 0;
    final hasCritical = (alertSummary?.criticalCount ?? 0) > 0;

    // Module default (riskRadar = danger) vs status override — here the
    // "status" is whether unread criticals exist at all. Per spec, status
    // always wins when present.
    final glowColor = HoverGlowColors.forModuleAndStatus(
      moduleColor: AppTheme.riskRadar,
      status: hasCritical ? 'CRITICAL' : null,
    );

    return HoverCard(
      glowColor: glowColor,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  HoverIconBadge(
                    icon: Icons.shield_rounded,
                    glowColor: AppTheme.riskRadar,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'RiskRadar Alerts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.danger.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '$unread new',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No alerts',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
            )
          else
            Column(
              children: [
                HoverEntrance(
                  index: 0,
                  child: _SeverityRow(
                    label: 'Critical',
                    count: alertSummary?.criticalCount ?? 0,
                    color: AppTheme.danger,
                  ),
                ),
                const SizedBox(height: 6),
                HoverEntrance(
                  index: 1,
                  child: _SeverityRow(
                    label: 'High',
                    count: alertSummary?.highCount ?? 0,
                    color: AppTheme.danger.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 6),
                HoverEntrance(
                  index: 2,
                  child: _SeverityRow(
                    label: 'Medium',
                    count: alertSummary?.mediumCount ?? 0,
                    color: AppTheme.warning,
                  ),
                ),
                const SizedBox(height: 6),
                HoverEntrance(
                  index: 3,
                  child: _SeverityRow(
                    label: 'Low',
                    count: alertSummary?.lowCount ?? 0,
                    color: AppTheme.info,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          HoverTextLink(
            text: 'View All Alerts →',
            onTap: () => context.go(AppConstants.routeAlerts),
          ),
        ],
      ),
    );
  }
}

class _SeverityRow extends StatelessWidget {
  const _SeverityRow({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return HoverListItem(
      glowColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}