/// Upcoming Billing Widget — Next 5 billing dates
/// Phase 2: rebuilt on HoverCard with HoverListItem rows (each row gets
/// its own hover zoom+glow), staggered entrance per row, dot color now
/// pulls from the subscription's real categoryColor when available
/// instead of a flat blue/warning split.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/subscription_models.dart';
import '../../../core/constants/app_constants.dart';

class UpcomingBillingWidget extends StatelessWidget {
  final List<SubscriptionResponse> subscriptions;

  const UpcomingBillingWidget({super.key, required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    final upcoming = subscriptions
        .where((s) => s.nextBillingDate.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    final visible = upcoming.take(5).toList();

    return HoverCard(
      glowColor: AppTheme.subVault,
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
                    icon: Icons.event_repeat_rounded,
                    glowColor: AppTheme.subVault,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Upcoming Billing',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              HoverTextLink(
                text: 'View All',
                onTap: () => context.go(AppConstants.routeSubscriptions),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No upcoming billing',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
            )
          else
            ...List.generate(visible.length, (i) {
              return HoverEntrance(
                index: i,
                child: _BillingRow(sub: visible[i]),
              );
            }),
        ],
      ),
    );
  }
}

class _BillingRow extends StatelessWidget {
  const _BillingRow({required this.sub});

  final SubscriptionResponse sub;

  Color get _dotColor {
    final hex = sub.categoryColor;
    if (hex != null && hex.isNotEmpty) {
      final cleaned = hex.replaceFirst('#', '');
      final value = int.tryParse('FF$cleaned', radix: 16);
      if (value != null) return Color(value);
    }
    return AppTheme.subVault;
  }

  @override
  Widget build(BuildContext context) {
    final daysUntil = sub.nextBillingDate.difference(DateTime.now()).inDays;
    final isUrgent = daysUntil <= 3;
    final dotColor = isUrgent ? AppTheme.warning : _dotColor;

    return HoverListItem(
      glowColor: dotColor,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  sub.categoryName,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${sub.currencySymbol}${sub.billingAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                isUrgent ? 'Tomorrow' : 'In $daysUntil days',
                style: TextStyle(
                  fontSize: 11,
                  color: isUrgent ? AppTheme.warning : AppTheme.textSecondary,
                  fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}