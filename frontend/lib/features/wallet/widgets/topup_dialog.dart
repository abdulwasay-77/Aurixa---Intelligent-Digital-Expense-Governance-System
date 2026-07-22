/// TopUpDialog — Phase 10 UI Enhancement
///
/// Hover classification:
///   Modal dialog, fixed/contained width (maxWidth: 400) — not a hover
///   surface itself, but every interactive element inside it uses the
///   shared primitives: HoverButton for Cancel/Add Funds, GlowFocusField
///   wrapping the amount field (continuously-cycling border glow on focus,
///   distinct from pointer-hover — this is the "actively being typed
///   into" treatment used for primary numeric inputs elsewhere).
///
/// Theme override safety (Lesson 4): this dialog renders on bgSurface
/// (light), and its DropdownButtonFormField items are styled explicitly
/// (dropdownColor + style) rather than relying on inherited Theme — same
/// pattern as Profile's preferences_form.dart dropdowns. No two-background
/// context here (no dark trigger bleeding into a light popup), so
/// selectedItemBuilder is not needed — Lesson 5 only applies when a
/// dropdown's trigger itself sits on a dark/gradient surface.
///
/// In-flight state (Lesson 11): _isLoading is already a local State bool,
/// set/cleared explicitly around the await — NOT derived from the
/// provider's AsyncValue. topUpWallet() calls refresh() internally, which
/// would otherwise collapse asyncState.value to null mid-flight. Kept as-is
/// from the pre-enhancement file, which already got this right.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/wallet_models.dart';
import '../../../providers/wallet_provider.dart';

class TopUpDialog extends ConsumerStatefulWidget {
  final List<WalletResponse> wallets;

  const TopUpDialog({super.key, required this.wallets});

  @override
  ConsumerState<TopUpDialog> createState() => _TopUpDialogState();
}

class _TopUpDialogState extends ConsumerState<TopUpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountFocus = FocusNode();

  late int _selectedWalletId;
  String _paymentMethod = 'Cash';

  // Local State bool — NOT derived from asyncState.value (Lesson 11).
  bool _isLoading = false;

  final _paymentMethods = ['Cash', 'Bank Transfer', 'Card', 'Online'];

  @override
  void initState() {
    super.initState();
    _selectedWalletId =
        widget.wallets.isNotEmpty ? widget.wallets.first.walletId : 0;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await ref.read(walletProvider.notifier).topUpWallet(
          walletId: _selectedWalletId,
          amount: double.parse(_amountCtrl.text.trim()),
          paymentMethod: _paymentMethod,
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet topped up successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Top-up failed. Please try again.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCards)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
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
                      icon: Icons.add_rounded,
                      glowColor: AppTheme.success,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Top Up Wallet',
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

                // ── Wallet selector ─────────────────────────────────────
                if (widget.wallets.length > 1) ...[
                  const Text('Select Wallet',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: _selectedWalletId,
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
                      if (v != null) setState(() => _selectedWalletId = v);
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Amount (GlowFocusField wrapped) ─────────────────────
                const Text('Amount',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                GlowFocusField(
                  focusNode: _amountFocus,
                  glowColors: const [
                    AppTheme.success,
                    AppTheme.brandIndigo,
                    AppTheme.success,
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
                      if (d == null || d <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // ── Payment method ───────────────────────────────────────
                const Text('Payment Method',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  dropdownColor: AppTheme.bgElevated,
                  decoration: const InputDecoration(),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  items: _paymentMethods.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _paymentMethod = v);
                  },
                ),
                const SizedBox(height: 14),

                // ── Description ──────────────────────────────────────────
                const Text('Note (Optional)',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Monthly salary',
                  ),
                  maxLength: 100,
                  maxLines: 1,
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
                        label: 'Add Funds',
                        icon: Icons.add_rounded,
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