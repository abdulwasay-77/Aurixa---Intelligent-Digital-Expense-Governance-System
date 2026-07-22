/// TransactionCard — Phase 10 UI Enhancement
///
/// Hover classification:
///   Dense list row — icon + title + category chip + timestamp + flags on
///   one line, amount block on the other side, stacked tightly in a long
///   scrolling list → HoverSize.subtle (1.045x). This carries noticeably
///   more inline content than a typical HoverListItem default
///   (HoverSize.small), so the gentler tier is the right call per Lesson 2
///   ("looks compact ≠ is compact") — a punchy 1.10x zoom on a row this
///   packed would feel jumpy against its neighbors above/below.
///
/// Glow color: status-override via HoverGlowColors.forModuleAndStatus.
///   - isAnomaly == true always wins and glows danger, regardless of type
///     (an anomalous transaction is the one thing on this card the user
///     most needs flagged).
///   - Otherwise: CREDIT/REFUND glow success-ish (GOOD), DEBIT falls back
///     to the wallet module default (brandBlue) — debits are the normal
///     case, not a warning state.
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/wallet_models.dart';

class TransactionCard extends StatelessWidget {
  final TransactionResponse transaction;

  const TransactionCard({super.key, required this.transaction});

  Color get _amountColor {
    switch (transaction.txnType) {
      case 'CREDIT':
        return AppTheme.success;
      case 'REFUND':
        return AppTheme.brandIndigo;
      case 'DEBIT':
      default:
        return AppTheme.danger;
    }
  }

  IconData get _typeIcon {
    if (transaction.subscriptionName != null) {
      return Icons.subscriptions_rounded;
    }
    switch (transaction.txnType) {
      case 'CREDIT':
        return Icons.arrow_downward_rounded;
      case 'REFUND':
        return Icons.replay_rounded;
      case 'DEBIT':
      default:
        return Icons.arrow_upward_rounded;
    }
  }

  Color get _iconBgColor {
    switch (transaction.txnType) {
      case 'CREDIT':
        return AppTheme.success.withValues(alpha: 0.12);
      case 'REFUND':
        return AppTheme.brandIndigo.withValues(alpha: 0.12);
      case 'DEBIT':
      default:
        return AppTheme.danger.withValues(alpha: 0.12);
    }
  }

  // Status string fed to HoverGlowColors.forModuleAndStatus. Anomaly always
  // wins; otherwise CREDIT/REFUND read as "GOOD", DEBIT defers to module
  // default (it's the routine case, not a warning).
  String? get _glowStatus {
    if (transaction.isAnomaly) return 'DANGER';
    if (transaction.isCredit) return 'GOOD';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = HoverGlowColors.forModuleAndStatus(
      moduleColor: AppTheme.wallet,
      status: _glowStatus,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverListItem(
        glowColor: glowColor,
        size: HoverSize.subtle,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: AppTheme.radiusInputs,
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon, color: _amountColor, size: 18),
            ),
            const SizedBox(width: 12),
            // Description & category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    transaction.description ??
                        transaction.subscriptionName ??
                        transaction.txnTypeLabel,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (transaction.categoryName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.bgBase.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transaction.categoryName!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        transaction.timeAgo,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      if (transaction.isRecurring) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.repeat_rounded,
                            size: 11, color: AppTheme.textMuted),
                      ],
                      if (transaction.isAnomaly) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.warning_amber_rounded,
                            size: 11, color: AppTheme.danger),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transaction.formattedAmount,
                  style: TextStyle(
                    color: _amountColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (transaction.amountUsd != null &&
                    transaction.walletCurrency != 'USD') ...[
                  const SizedBox(height: 2),
                  Text(
                    '\$${transaction.amountUsd!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}