/// ScoreCore Widget — Financial Health Score Ring
/// Phase 2: rebuilt on HoverCard (module color = AppTheme.scoreCore),
/// gradient-accented ring track, refined badge treatment.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/analytics_models.dart';

class ScoreCoreWidget extends StatelessWidget {
  final FinancialScoreResponse? score;

  const ScoreCoreWidget({super.key, this.score});

  @override
  Widget build(BuildContext context) {
    final healthScore = score?.financialHealthScore ?? 0;
    final scoreLabel = score?.scoreLabel ?? 'NOT_CALCULATED';
    final percentage = (healthScore / 100).clamp(0.0, 1.0);
    final scoreColor = _getScoreColor(healthScore);

    return HoverCard(
      glowColor: AppTheme.scoreCore,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Financial Health',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              HoverIconBadge(
                icon: Icons.favorite_rounded,
                glowColor: AppTheme.scoreCore,
                size: 32,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 12,
                  backgroundColor: AppTheme.bgElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${healthScore.toInt()}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusBadges),
              border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              scoreLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scoreColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return AppTheme.primary;
    if (score >= 40) return AppTheme.warning;
    return AppTheme.danger;
  }
}