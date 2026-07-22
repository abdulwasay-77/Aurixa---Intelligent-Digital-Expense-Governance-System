/// TransferDialog — Phase 10 UI Enhancement
///
/// Hover classification: same rationale as TopUpDialog — modal surface,
///   not itself a hover target; interactive children use the shared
///   primitives (HoverIconBadge header icon, HoverButton actions,
///   GlowFocusField on the amount input).
///
/// In-flight state (Lesson 11): _isLoading is a local State bool, set
///   before / cleared after the await, independent of the provider's
///   AsyncValue — transferBetweenWallets() calls refresh() internally,
///   which would otherwise null out asyncState.value mid-flight.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/wallet_models.dart';
import '../../../providers/wallet_provider.dart';

class TransferDialog extends ConsumerStatefulWidget {
  final List<WalletResponse> wallets;

  const TransferDialog({super.key, required this.wallets});

  @override
  ConsumerState<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<TransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountFocus = FocusNode();

  late int _fromWalletId;
  late int _toWalletId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fromWalletId =
        widget.wallets.isNotEmpty ? widget.wallets.first.walletId : 0;
    _toWalletId = widget.wallets.length > 1
        ? widget.wallets[1].walletId
        : (widget.wallets.isNotEmpty ? widget.wallets.first.walletId : 0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  WalletResponse? _walletById(int id) {
    try {
      return widget.wallets.firstWhere((w) => w.walletId == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromWalletId == _toWalletId) {
      setState(() => _errorMessage = 'Source and destination must differ.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final err =
        await ref.read(walletProvider.notifier).transferBetweenWallets(
              fromWalletId: _fromWalletId,
              toWalletId: _toWalletId,
              amount: double.parse(_amountCtrl.text.trim()),
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
            );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (err == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer completed successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      setState(() => _errorMessage = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromWallet = _walletById(_fromWalletId);

    return Dialog(
      backgroundColor: AppTheme.bgSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCards)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  children: [
                    HoverIconBadge(
                      icon: Icons.swap_horiz_rounded,
                      glowColor: AppTheme.brandIndigo,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Transfer Funds',
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Error banner ────────────────────────────────────────
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.danger, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.danger, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── From wallet ─────────────────────────────────────────
                const Text('From Wallet',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: _fromWalletId,
                  dropdownColor: AppTheme.bgElevated,
                  decoration: const InputDecoration(),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  items: widget.wallets.map((w) {
                    return DropdownMenuItem(
                      value: w.walletId,
                      child: Text(
                          '${w.walletTypeLabel} (${w.currencyCode.trim()}) — ${w.formattedBalance}'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _fromWalletId = v);
                  },
                ),
                const SizedBox(height: 4),

                if (fromWallet != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Available: ${fromWallet.formattedBalance}',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 14),

                // ── Transfer arrow indicator — small isolated badge ─────
                Center(
                  child: HoverIconBadge(
                    icon: Icons.arrow_downward_rounded,
                    glowColor: AppTheme.brandIndigo,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),

                // ── To wallet ────────────────────────────────────────────
                const Text('To Wallet',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: _toWalletId,
                  dropdownColor: AppTheme.bgElevated,
                  decoration: const InputDecoration(),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  items: widget.wallets.map((w) {
                    return DropdownMenuItem(
                      value: w.walletId,
                      child: Text(
                          '${w.walletTypeLabel} (${w.currencyCode.trim()}) — ${w.formattedBalance}'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _toWalletId = v);
                  },
                ),
                const SizedBox(height: 14),

                // ── Amount (GlowFocusField wrapped) ─────────────────────
                const Text('Amount',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                GlowFocusField(
                  focusNode: _amountFocus,
                  glowColors: const [
                    AppTheme.brandBlue,
                    AppTheme.brandIndigo,
                    AppTheme.brandPurple,
                  ],
                  child: TextFormField(
                    controller: _amountCtrl,
                    focusNode: _amountFocus,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.attach_money,
                          color: AppTheme.textSecondary, size: 18),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter an amount';
                      final d = double.tryParse(v);
                      if (d == null || d <= 0) {
                        return 'Enter a valid amount greater than 0';
                      }
                      if (fromWallet != null && d > fromWallet.balance) {
                        return 'Amount exceeds available balance';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // ── Note ──────────────────────────────────────────────────
                const Text('Note (Optional)',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration:
                      const InputDecoration(hintText: 'e.g. Moving savings'),
                  maxLength: 100,
                ),
                const SizedBox(height: 12),

                // ── Buttons ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: HoverButton(
                        label: 'Cancel',
                        outlined: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: HoverButton(
                        label: 'Transfer',
                        icon: Icons.swap_horiz_rounded,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}