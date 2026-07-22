/// Subscription Card Widget — Individual subscription display
/// Phase 3: rebuilt on HoverCard with scaleEnabled: true (per spec — the
/// list uses generous vertical spacing between cards specifically so the
/// zoom never overlaps a neighbor, unlike the Phase 2 sidebar mistake).
/// Round 3 fix: a one-off scaleOverride wasn't the right tool here — the
/// real fix is a proper named, reusable scale tier. Added
/// HoverSize.subtle to hover_widgets.dart (AppTheme.hoverScaleSubtle =
/// 1.045x) specifically for tall/dense list cards like this one that
/// still want a real, noticeable zoom, just gentler than the standard
/// large-card 1.08x. Any future card that needs the same treatment picks
/// this size, rather than every screen inventing its own magic number.
/// Module accent = AppTheme.subVault, with the card's own category color
/// used for its icon badge so each row still reads distinctly within the
/// list. Action icon buttons use HoverIconBadge for consistency with the
/// rest of the app's hover vocabulary.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/subscription_models.dart';

class SubscriptionCard extends StatelessWidget {
  final SubscriptionResponse subscription;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback? onUsageUpdate;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    required this.onEdit,
    required this.onCancel,
    this.onUsageUpdate,
  });

  Color get _categoryColor {
    final hex = subscription.categoryColor;
    if (hex != null && hex.isNotEmpty) {
      final cleaned = hex.replaceFirst('#', '');
      final value = int.tryParse('FF$cleaned', radix: 16);
      if (value != null) return Color(value);
    }
    return AppTheme.subVault;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = subscription.isActive;
    final usagePercentage = subscription.usageScore / 10;
    final categoryColor = _categoryColor;

    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: HoverCard(
        glowColor: AppTheme.subVault,
        padding: const EdgeInsets.all(18),
        // Named, reusable tier — not a one-off magic number. Pick this
        // size for any tall/dense list card that wants a real but
        // gentler zoom than the standard large-card default.
        size: HoverSize.subtle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(subscription.categoryIcon),
                    color: categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.serviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subscription.categoryName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(),
              ],
            ),
            const SizedBox(height: 16),

            // Details Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${subscription.currencySymbol}${subscription.billingAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '/ ${subscription.cycleLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Next Billing',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(subscription.nextBillingDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (isActive) _buildDaysUntilBadge(),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Usage',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: List.generate(5, (index) {
                          final filled = index < usagePercentage * 5;
                          return Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: filled
                                ? _getUsageColor(subscription.usageScore)
                                : AppTheme.borderColor,
                          );
                        }),
                      ),
                      Text(
                        '${subscription.usageScore}/10',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 10),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!subscription.isCancelled) ...[
                  HoverIconBadge(
                    icon: Icons.star_rate_rounded,
                    glowColor: AppTheme.warning,
                    size: 34,
                    onTap: onUsageUpdate,
                  ),
                  const SizedBox(width: 8),
                  HoverIconBadge(
                    icon: Icons.edit_rounded,
                    glowColor: AppTheme.subVault,
                    size: 34,
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 8),
                  HoverIconBadge(
                    icon: Icons.cancel_rounded,
                    glowColor: AppTheme.danger,
                    size: 34,
                    onTap: onCancel,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;

    if (subscription.isCancelled) {
      color = AppTheme.textMuted;
      label = 'CANCELLED';
    } else if (subscription.isPaused) {
      color = AppTheme.warning;
      label = 'PAUSED';
    } else {
      color = AppTheme.success;
      label = 'ACTIVE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusBadges),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildDaysUntilBadge() {
    final daysUntil = subscription.nextBillingDate.difference(DateTime.now()).inDays;
    if (daysUntil < 0) return const SizedBox.shrink();

    final isUrgent = daysUntil <= 3;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isUrgent ? AppTheme.warning.withValues(alpha: 0.18) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        daysUntil == 0 ? 'Today' : '${daysUntil}d',
        style: TextStyle(
          fontSize: 10,
          fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal,
          color: isUrgent ? AppTheme.warning : AppTheme.textSecondary,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return 'Tomorrow';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'play_circle': return Icons.play_circle_rounded;
      case 'music_note': return Icons.music_note_rounded;
      case 'build': return Icons.build_rounded;
      case 'sports_esports': return Icons.sports_esports_rounded;
      case 'cloud': return Icons.cloud_rounded;
      case 'shield': return Icons.shield_rounded;
      case 'bolt': return Icons.bolt_rounded;
      case 'menu_book': return Icons.menu_book_rounded;
      case 'auto_awesome': return Icons.auto_awesome_rounded;
      case 'fitness_center': return Icons.fitness_center_rounded;
      default: return Icons.subscriptions_rounded;
    }
  }

  Color _getUsageColor(int score) {
    if (score >= 8) return AppTheme.success;
    if (score >= 5) return AppTheme.primary;
    if (score >= 3) return AppTheme.warning;
    return AppTheme.danger;
  }
}