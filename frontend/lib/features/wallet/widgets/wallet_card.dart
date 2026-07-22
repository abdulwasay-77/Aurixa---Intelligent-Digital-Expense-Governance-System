/// WalletCard — Phase 10 UI Enhancement
///
/// Hover classification:
///   Fixed-size (240×140), isolated card in a horizontally-scrolling row
///   with real gutters (14px separators) on every side → HoverSize.large.
///   This is the single biggest element on the Wallet screen, but it's also
///   the most isolated — a punchy-but-capped 1.08x zoom never collides with
///   its neighbors because the ListView gives it breathing room and the
///   scale is centered on a fixed box, not a flex child.
///
/// Glow color: type-based via HoverGlowColors.forModuleAndStatus — PRIMARY
/// uses the wallet module accent (brandBlue), SAVINGS glows success,
/// FOREIGN glows the brand indigo/violet family. Falls back to the wallet
/// module default for unrecognised types.
///
/// Gradient body fill kept as the existing per-type gradient (it's the
/// card's own "skin", same as a real wallet/card UI) — the hover glow sits
/// outside that as a border + shadow bloom, consistent with HoverGlow's
/// layering on every other module.
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/wallet_models.dart';

class WalletCard extends StatelessWidget {
  final WalletResponse wallet;
  final bool isSelected;
  final VoidCallback? onTap;

  const WalletCard({
    super.key,
    required this.wallet,
    this.isSelected = false,
    this.onTap,
  });

  Color get _accentColor {
    switch (wallet.walletType) {
      case 'PRIMARY':
        return AppTheme.wallet;
      case 'SAVINGS':
        return AppTheme.success;
      case 'FOREIGN':
        return AppTheme.brandIndigo;
      default:
        return AppTheme.brandPurple;
    }
  }

  IconData get _walletIcon {
    switch (wallet.walletType) {
      case 'PRIMARY':
        return Icons.account_balance_wallet_rounded;
      case 'SAVINGS':
        return Icons.savings_rounded;
      case 'FOREIGN':
        return Icons.currency_exchange_rounded;
      default:
        return Icons.wallet_rounded;
    }
  }

  List<Color> get _gradientColors {
    switch (wallet.walletType) {
      case 'PRIMARY':
        return [AppTheme.brandBlue, AppTheme.primaryDark];
      case 'SAVINGS':
        return [AppTheme.success, const Color(0xFF26A375)];
      case 'FOREIGN':
        return [AppTheme.brandIndigo, AppTheme.brandPurple];
      default:
        return [AppTheme.brandPurple, AppTheme.brandIndigo];
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverGlow(
      glowColor: _accentColor,
      size: HoverSize.large,
      onTap: onTap,
      borderRadius: AppTheme.radiusCards,
      border: false, // card already has its own gradient edge via boxShadow
      backgroundColor: Colors.transparent,
      child: Container(
        width: 240,
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusCards),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(_walletIcon,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 18),
                      const SizedBox(width: 6),
                      Text(
                        wallet.walletTypeLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  // Currency badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      wallet.currencyCode.trim(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Balance
              Text(
                wallet.formattedBalance,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Wallet #${wallet.walletId}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}