/// WalletScreen — Phase 10 UI Enhancement
/// Golden Rule: Oracle computes. Python narrates. Flutter displays.
///
/// Module accent: AppTheme.wallet (brandBlue). Hero header gradient:
/// brandBlue → brandIndigo (matching SubVault/BehaviorLens/VelocityEngine/
/// RiskRadar/Recommendations vocabulary).
///
/// Hover classification (applied before writing any widget code):
///   • Hero balance summary — wide, full-width banner, NOT compact/isolated
///     → wrapped in HoverEntrance for fade+slide only; no hover-zoom on the
///     banner itself (same treatment as every other module's hero header).
///   • WalletCard (horizontal scroll row) — fixed 240×140, isolated, real
///     gutters on all sides → HoverSize.large. See wallet_card.dart header
///     comment for the full rationale on why the biggest element on this
///     screen still gets the gentlest of the three *enabled* tiers, not a
///     one-off override.
///   • Action buttons (Top Up / Transfer) — compact, isolated, 2-across row
///     with a real gutter between them → HoverCard(size: HoverSize.large).
///   • Monthly spending rows — wide, dense (label + bar + 2 sub-labels +
///     txn count packed into one row) → HoverSize.subtle, same as
///     Recommendations' stat tiles / RiskRadar's AlertCard (Lesson 2:
///     "looks compact ≠ is compact").
///   • Transaction rows — handled inside TransactionList/TransactionCard
///     (HoverSize.subtle, dense list row).
///
/// Layout safety:
///   • Hero Container has width: double.infinity (Lesson 8).
///   • Wallet/transaction data is null-guarded before rendering — nothing
///     here renders ahead of the provider's AsyncData.
///   • No Expanded is ever the direct child of HoverEntrance anywhere in
///     this file (Lesson 10) — every wrap is `Expanded(child: HoverEntrance(...))`
///     or HoverEntrance wraps a fixed/intrinsic-size child only.
///   • No continuously-repeating AnimationController lives on an ancestor
///     of a ListView item (Lesson 7) — this screen owns no AnimationController
///     at all; GlowFocusField's cycling controller (used in the dialogs)
///     is scoped to the dialog's own State, not this screen.
///   • Dialog dropdowns render only on light surfaces (Dialog → bgSurface),
///     so no two-background-context handling is needed (Lesson 5 doesn't
///     apply here — see topup_dialog.dart header note).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet_models.dart';
import 'widgets/wallet_card.dart';
import 'widgets/transaction_list.dart';
import 'widgets/topup_dialog.dart';
import 'widgets/transfer_dialog.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  int? _selectedWalletIndex;

  // ── Dialogs ────────────────────────────────────────────────────────────

  void _showTopUp(List<WalletResponse> wallets) {
    showDialog(
      context: context,
      builder: (_) => TopUpDialog(wallets: wallets),
    );
  }

  void _showTransfer(List<WalletResponse> wallets) {
    if (wallets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'You need at least 2 wallets to transfer funds. Add a Savings or Foreign wallet first.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => TransferDialog(wallets: wallets),
    );
  }

  void _showCreateWallet() {
    String selectedCurrency = 'USD';
    String selectedType = 'SAVINGS';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: AppTheme.bgSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusCards)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HoverIconBadge(
                        icon: Icons.add_card_rounded,
                        glowColor: AppTheme.wallet,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'New Wallet',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppTheme.textSecondary, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Wallet Type',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: AppTheme.bgElevated,
                    decoration: const InputDecoration(),
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    items: const [
                      DropdownMenuItem(
                          value: 'SAVINGS', child: Text('Savings')),
                      DropdownMenuItem(
                          value: 'FOREIGN', child: Text('Foreign Currency')),
                    ],
                    onChanged: (v) {
                      if (v != null) setS(() => selectedType = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Currency',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCurrency,
                    dropdownColor: AppTheme.bgElevated,
                    decoration: const InputDecoration(),
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    items: const [
                      DropdownMenuItem(
                          value: 'USD', child: Text('USD — US Dollar')),
                      DropdownMenuItem(
                          value: 'EUR', child: Text('EUR — Euro')),
                      DropdownMenuItem(
                          value: 'GBP', child: Text('GBP — British Pound')),
                      DropdownMenuItem(
                          value: 'PKR',
                          child: Text('PKR — Pakistani Rupee')),
                    ],
                    onChanged: (v) {
                      if (v != null) setS(() => selectedCurrency = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: HoverButton(
                          label: 'Cancel',
                          outlined: true,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: HoverButton(
                          label: 'Create',
                          icon: Icons.add_card_rounded,
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            final ok = await ref
                                .read(walletProvider.notifier)
                                .createWallet(
                                  currencyCode: selectedCurrency,
                                  walletType: selectedType,
                                );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'Wallet created successfully!'
                                      : 'Failed to create wallet.'),
                                  backgroundColor:
                                      ok ? AppTheme.success : AppTheme.danger,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: walletAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.wallet),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 48, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Could not load wallet data.\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                HoverButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  expand: false,
                  onPressed: () =>
                      ref.read(walletProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
        ),
        data: (state) => _WalletContent(
          state: state,
          selectedIndex: _selectedWalletIndex,
          onSelectWallet: (i) => setState(() => _selectedWalletIndex = i),
          onTopUp: () => _showTopUp(state.walletList?.wallets ?? []),
          onTransfer: () => _showTransfer(state.walletList?.wallets ?? []),
          onCreateWallet: _showCreateWallet,
          onRefresh: () => ref.read(walletProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Main Content
// ══════════════════════════════════════════════════════════════════════════

class _WalletContent extends StatelessWidget {
  final WalletState state;
  final int? selectedIndex;
  final ValueChanged<int?> onSelectWallet;
  final VoidCallback onTopUp;
  final VoidCallback onTransfer;
  final VoidCallback onCreateWallet;
  final VoidCallback onRefresh;

  const _WalletContent({
    required this.state,
    required this.selectedIndex,
    required this.onSelectWallet,
    required this.onTopUp,
    required this.onTransfer,
    required this.onCreateWallet,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final wallets = state.walletList?.wallets ?? [];
    final totalUsd = state.walletList?.totalBalanceUsd ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero header ───────────────────────────────────────────────
          _buildHeroHeader(totalUsd, wallets.length, onRefresh),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Wallet cards row ────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Wallets',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    HoverTextLink(
                      text: '+ Add Wallet',
                      onTap: onCreateWallet,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (wallets.isEmpty)
                  const _EmptyWallets()
                else
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: wallets.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 14),
                      itemBuilder: (_, i) => HoverEntrance(
                        index: i,
                        child: WalletCard(
                          wallet: wallets[i],
                          isSelected: selectedIndex == i,
                          onTap: () =>
                              onSelectWallet(selectedIndex == i ? null : i),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // ── Action buttons ───────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: HoverEntrance(
                        index: 0,
                        child: _ActionTile(
                          icon: Icons.add_rounded,
                          label: 'Top Up',
                          color: AppTheme.success,
                          onTap: onTopUp,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HoverEntrance(
                        index: 1,
                        child: _ActionTile(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Transfer',
                          color: AppTheme.brandIndigo,
                          onTap: onTransfer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Monthly spending summary ─────────────────────────────
                if (state.monthlySpending.isNotEmpty) ...[
                  _MonthlySpendingSection(spending: state.monthlySpending),
                  const SizedBox(height: 24),
                ],

                // ── Transaction history ──────────────────────────────────
                const TransactionList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // Hero Header
  //
  // width: double.infinity is REQUIRED — without a concrete width
  // constraint here, the Row's children below measure against infinite
  // width and the layout breaks (Lesson 8).
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildHeroHeader(
      double totalUsd, int walletCount, VoidCallback onRefresh) {
    return HoverEntrance(
      index: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.wallet, AppTheme.brandIndigo],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title row ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Wallet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Refresh — glass icon button, header action vocabulary
                // shared with RiskRadar/Recommendations.
                _GlassIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onTap: onRefresh,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Balance block ──────────────────────────────────────────
            const Text(
              'Total Balance (USD)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '\$${totalUsd.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Across $walletCount wallet${walletCount != 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// _GlassIconButton — header action button, glass tile vocabulary matching
// other modules' hero headers. Small, isolated → HoverSize.small via
// HoverIconBadge-equivalent treatment.
// ══════════════════════════════════════════════════════════════════════════

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovering ? AppTheme.hoverScaleSmall : 1.0,
          duration: AppTheme.hoverDuration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: Curves.easeOut,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hovering ? 0.28 : 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
    return widget.tooltip != null
        ? Tooltip(message: widget.tooltip!, child: button)
        : button;
  }
}

// ══════════════════════════════════════════════════════════════════════════
// _ActionTile — Top Up / Transfer buttons.
// Compact, isolated, 2-across with real gutter → HoverSize.large.
// ══════════════════════════════════════════════════════════════════════════

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Using HoverGlow directly (not HoverCard) because this tile needs a
    // custom tinted backgroundColor — HoverCard is a thin HoverGlow +
    // Padding wrapper but does NOT forward backgroundColor, only glowColor/
    // size/onTap/borderRadius/scaleEnabled/scaleOverride. Passing
    // backgroundColor to HoverCard is a compile error (no such parameter).
    return HoverGlow(
      glowColor: color,
      size: HoverSize.large,
      onTap: onTap,
      backgroundColor: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Monthly Spending Section
// Each row is wide/dense (label + bar + 2 sub-labels + txn count) →
// HoverSize.subtle (Lesson 2).
// ══════════════════════════════════════════════════════════════════════════

class _MonthlySpendingSection extends StatelessWidget {
  final List<MonthlySpendingResponse> spending;

  const _MonthlySpendingSection({required this.spending});

  @override
  Widget build(BuildContext context) {
    final recent = spending.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Monthly Spending',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...recent.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HoverEntrance(
                  index: e.key,
                  child: _MonthlyRow(data: e.value),
                ),
              ),
            ),
      ],
    );
  }
}

class _MonthlyRow extends StatelessWidget {
  final MonthlySpendingResponse data;

  const _MonthlyRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final subPct = data.totalSpent > 0
        ? (data.subscriptionSpent / data.totalSpent).clamp(0.0, 1.0)
        : 0.0;

    return HoverCard(
      glowColor: AppTheme.wallet,
      size: HoverSize.subtle,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: AppTheme.radiusInputs,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.monthLabel,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '\$${data.totalSpent.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              width: double.infinity,
              child: Row(
                children: [
                  Flexible(
                    flex: (subPct * 100).round().clamp(1, 100),
                    child: Container(color: AppTheme.wallet),
                  ),
                  Flexible(
                    flex: ((1 - subPct) * 100).round().clamp(1, 100),
                    child: Container(color: AppTheme.bgSurface),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _SpendLabel(
                color: AppTheme.wallet,
                label: 'Subs',
                amount: data.subscriptionSpent,
              ),
              const SizedBox(width: 12),
              _SpendLabel(
                color: AppTheme.textMuted,
                label: 'Other',
                amount: data.otherSpent,
              ),
              const Spacer(),
              Text(
                '${data.transactionCount} txns',
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpendLabel extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;

  const _SpendLabel(
      {required this.color, required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(
          '$label: \$${amount.toStringAsFixed(0)}',
          style: TextStyle(color: color, fontSize: 11),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Empty State
// ══════════════════════════════════════════════════════════════════════════

class _EmptyWallets extends StatelessWidget {
  const _EmptyWallets();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 48, color: AppTheme.textMuted),
          SizedBox(height: 8),
          Text(
            'No wallets found.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}