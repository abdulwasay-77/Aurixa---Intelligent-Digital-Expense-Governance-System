/// Preferences Form Widget — Financial settings + notification preferences
///
/// Shape classification: both sections are tall, field-dense forms (an
/// income field, a slider, two dropdowns, and a button in one card; three
/// toggle rows and a button in the other). Per the hover_widgets.dart
/// rule — "Tall/variable-height or text-heavy → border+glow only, no
/// zoom" — both section cards use scaleEnabled: false. A punchy zoom on
/// a card this tall would push well past its own footprint in the
/// scroll column and visually collide with the card above/below it,
/// which is exactly the "overshadowing neighbors" failure mode the
/// size-aware hover system exists to avoid.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../providers/profile_provider.dart';

class PreferencesForm extends StatefulWidget {
  final UserProfile profile;
  final UserPreferences preferences;
  final Future<bool> Function({
    double? monthlyIncome,
    double? savingTargetPct,
    String? riskTolerance,
    String? baseCurrencyCode,
  }) onUpdateProfile;
  final Future<bool> Function({
    bool? notifBudgetAlert,
    bool? notifBillingReminder,
    bool? notifAnomaly,
    String? theme,
    bool? biometricEnabled,
  }) onUpdatePreferences;

  const PreferencesForm({
    super.key,
    required this.profile,
    required this.preferences,
    required this.onUpdateProfile,
    required this.onUpdatePreferences,
  });

  @override
  State<PreferencesForm> createState() => _PreferencesFormState();
}

class _PreferencesFormState extends State<PreferencesForm> {
  final _incomeCtrl = TextEditingController();
  // GlowFocusField is self-contained (owns its own internal cycling
  // controller — see hover_widgets.dart), but it still needs a
  // caller-owned FocusNode to know when to activate. This screen is not
  // a ListView item, so owning this FocusNode here is safe (Lesson 7
  // only restricts continuously-ticking controllers, and GlowFocusField
  // only runs its cycle while genuinely focused).
  final _incomeFocusNode = FocusNode();

  late double _savingTarget;
  late String _riskTolerance;
  late String _currency;

  late bool _notifBudget;
  late bool _notifBilling;
  late bool _notifAnomaly;

  bool _savingProfile = false;
  bool _savingPrefs = false;

  @override
  void initState() {
    super.initState();
    _incomeCtrl.text = widget.profile.monthlyIncome.toStringAsFixed(0);
    _savingTarget = widget.profile.savingTargetPct;
    _riskTolerance = widget.profile.riskTolerance;
    _currency = widget.profile.baseCurrencyCode;

    _notifBudget = widget.preferences.notifBudgetAlert;
    _notifBilling = widget.preferences.notifBillingReminder;
    _notifAnomaly = widget.preferences.notifAnomaly;
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _incomeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Financial Settings ─────────────────────────────────
        _buildSection(
          title: 'Financial Settings',
          icon: Icons.attach_money,
          children: [
            _buildIncomeField(),
            const SizedBox(height: 20),
            _buildSavingSlider(),
            const SizedBox(height: 20),
            _buildRiskDropdown(),
            const SizedBox(height: 20),
            _buildCurrencyDropdown(),
            const SizedBox(height: 20),
            _buildSaveProfileButton(),
          ],
        ),
        const SizedBox(height: 16),

        // ── Notification Preferences ───────────────────────────
        _buildSection(
          title: 'Notification Preferences',
          icon: Icons.notifications_outlined,
          children: [
            _buildToggleTile(
              title: 'Budget Alerts',
              subtitle: 'Notify when approaching budget limit',
              value: _notifBudget,
              onChanged: (v) => setState(() => _notifBudget = v),
              icon: Icons.account_balance_wallet_outlined,
              color: AppTheme.danger,
            ),
            _buildToggleTile(
              title: 'Billing Reminders',
              subtitle: 'Upcoming subscription payment reminders',
              value: _notifBilling,
              onChanged: (v) => setState(() => _notifBilling = v),
              icon: Icons.receipt_long_outlined,
              color: AppTheme.warning,
            ),
            _buildToggleTile(
              title: 'Anomaly Detection',
              subtitle: 'Alert on unusual spending patterns',
              value: _notifAnomaly,
              onChanged: (v) => setState(() => _notifAnomaly = v),
              icon: Icons.radar,
              color: AppTheme.profileAccent,
            ),
            const SizedBox(height: 8),
            _buildSavePrefsButton(),
          ],
        ),
      ],
    );
  }

  // ── Private builders ──────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return HoverCard(
      glowColor: AppTheme.profileAccent,
      // Tall, field-dense form → glow/border only, no zoom. See class doc.
      scaleEnabled: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.profileAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildIncomeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Monthly Income (${widget.profile.baseCurrencySymbol})'),
        const SizedBox(height: 8),
        // GlowFocusField — focus-reactive gradient border, same "actively
        // being typed into" treatment used for SubVault's search field.
        GlowFocusField(
          focusNode: _incomeFocusNode,
          borderRadius: AppTheme.radiusInputs,
          child: TextField(
            controller: _incomeCtrl,
            focusNode: _incomeFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            cursorColor: AppTheme.profileAccent,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              // GlowFocusField already owns an opaque bgElevated
              // background — disable the global theme fill so it
              // doesn't compete (same fix as the SubVault search bar).
              filled: false,
              prefixIcon: Icon(Icons.attach_money,
                  size: 18, color: AppTheme.textSecondary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavingSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label('Saving Target'),
            Text(
              '${_savingTarget.toInt()}%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.profileAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.profileAccent,
            inactiveTrackColor: AppTheme.bgElevated,
            thumbColor: AppTheme.profileAccent,
            overlayColor: AppTheme.profileAccent.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: _savingTarget,
            min: 0,
            max: 80,
            divisions: 16,
            onChanged: (v) => setState(() => _savingTarget = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0%', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text('40%', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text('80%', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRiskDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Risk Tolerance'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _riskTolerance,
          dropdownColor: AppTheme.bgSurface,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: _inputDeco(prefixIcon: Icons.shield_outlined),
          items: const [
            DropdownMenuItem(value: 'LOW', child: Text('Low — Conservative')),
            DropdownMenuItem(value: 'MEDIUM', child: Text('Medium — Balanced')),
            DropdownMenuItem(value: 'HIGH', child: Text('High — Aggressive')),
          ],
          onChanged: (v) => setState(() => _riskTolerance = v!),
        ),
      ],
    );
  }

  Widget _buildCurrencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Base Currency'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _currency,
          dropdownColor: AppTheme.bgSurface,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: _inputDeco(prefixIcon: Icons.currency_exchange),
          items: const [
            DropdownMenuItem(value: 'USD', child: Text('\$ USD — US Dollar')),
            DropdownMenuItem(value: 'EUR', child: Text('€ EUR — Euro')),
            DropdownMenuItem(value: 'GBP', child: Text('£ GBP — British Pound')),
            DropdownMenuItem(value: 'PKR', child: Text('Rs PKR — Pakistani Rupee')),
          ],
          onChanged: (v) => setState(() => _currency = v!),
        ),
      ],
    );
  }

  Widget _buildSaveProfileButton() {
    return HoverButton(
      label: _savingProfile ? 'Saving...' : 'Save Financial Settings',
      icon: Icons.save_outlined,
      isLoading: _savingProfile,
      onPressed: _savingProfile ? null : _saveProfile,
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color color,
  }) {
    // Whole row is hoverable/clickable to flip the switch — wide, dense
    // row → HoverSize.subtle (same reasoning as the Account Actions
    // rows on the main profile screen).
    return HoverListItem(
      glowColor: color,
      size: HoverSize.subtle,
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.profileAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildSavePrefsButton() {
    return HoverButton(
      label: _savingPrefs ? 'Saving...' : 'Save Notification Settings',
      icon: Icons.notifications_active_outlined,
      isLoading: _savingPrefs,
      outlined: true,
      onPressed: _savingPrefs ? null : _savePrefs,
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
      );

  InputDecoration _inputDeco({required IconData prefixIcon}) => InputDecoration(
        prefixIcon: Icon(prefixIcon, size: 18, color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.profileAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final income = double.tryParse(_incomeCtrl.text.trim());
    if (income == null || income <= 0) {
      _showSnack('Please enter a valid monthly income', isError: true);
      return;
    }

    setState(() => _savingProfile = true);
    final ok = await widget.onUpdateProfile(
      monthlyIncome: income,
      savingTargetPct: _savingTarget,
      riskTolerance: _riskTolerance,
      baseCurrencyCode: _currency,
    );
    if (mounted) setState(() => _savingProfile = false);

    if (ok) {
      _showSnack('Financial settings updated successfully');
    } else {
      _showSnack('Failed to update settings', isError: true);
    }
  }

  Future<void> _savePrefs() async {
    setState(() => _savingPrefs = true);
    final ok = await widget.onUpdatePreferences(
      notifBudgetAlert: _notifBudget,
      notifBillingReminder: _notifBilling,
      notifAnomaly: _notifAnomaly,
    );
    if (mounted) setState(() => _savingPrefs = false);

    if (ok) {
      _showSnack('Notification settings updated');
    } else {
      _showSnack('Failed to update notifications', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}