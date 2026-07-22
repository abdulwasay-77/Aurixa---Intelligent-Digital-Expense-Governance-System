/// VelocityEngine Gauge Widget — Budget Usage
/// Phase 2: rebuilt on HoverCard (module color = AppTheme.velocityEngine),
/// status-aware glow override when budget is breached.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class VelocityGaugeWidget extends StatelessWidget {
  final CurrentMonthForecast? forecast;

  const VelocityGaugeWidget({super.key, this.forecast});

  @override
  Widget build(BuildContext context) {
    final spent = forecast?.spentSoFar ?? 0;
    final budget = forecast?.budgetLimit ?? 1;
    final percentage = (spent / budget).clamp(0.0, 1.0);
    final isBreached = spent > budget;
    final barColor = isBreached ? AppTheme.danger : AppTheme.velocityEngine;

    // Status override per the locked hover-glow rule: a breached budget
    // glows danger-red even though VelocityEngine's default module color
    // is brandIndigo.
    final glowColor = HoverGlowColors.forModuleAndStatus(
      moduleColor: AppTheme.velocityEngine,
      status: forecast?.status == 'BREACHED' ? 'CRITICAL' : null,
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
              const Text(
                'Budget Status',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              HoverIconBadge(
                icon: Icons.speed_rounded,
                glowColor: AppTheme.velocityEngine,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${spent.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '/ \$${budget.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: AppTheme.bgElevated,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(percentage * 100).toInt()}% used',
                style: TextStyle(
                  fontSize: 12,
                  color: isBreached ? AppTheme.danger : AppTheme.textSecondary,
                ),
              ),
              if (forecast?.daysToBreach != null && forecast!.daysToBreach! > 0)
                Text(
                  '⚠️ ${forecast!.daysToBreach} days to breach',
                  style: const TextStyle(fontSize: 12, color: AppTheme.warning),
                ),
            ],
          ),
          if (forecast?.status == 'BREACHED')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusBadges),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, size: 16, color: AppTheme.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Budget breached by \$${(spent - budget).toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}