/// Add/Edit Subscription Dialog
///
/// Phase 3 rebuild:
///   BUG FIX — previously this dialog only ever built a
///   CreateSubscriptionRequest via a single `onSave` callback, even when
///   editing. SubscriptionNotifier.updateSubscription actually expects an
///   UpdateSubscriptionRequest — a different shape (all fields optional,
///   no startDate, includes status). Calling it with the wrong request
///   type would fail at the API boundary on every edit. Fixed by giving
///   the dialog two distinct callbacks — onSave (create) and onUpdate
///   (update) — and building the matching request type for whichever
///   mode is active. Exactly one of the two is required, matched to
///   whether `subscription` is null (add) or not (edit).
///
///   Visual pass: gradient header band matching the SubVault hero header,
///   sectioned fields, HoverButton actions instead of bare
///   Elevated/OutlinedButton.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/subscription_models.dart';

class AddEditSubscriptionDialog extends StatefulWidget {
  final SubscriptionResponse? subscription;

  /// Called with a CreateSubscriptionRequest when adding a new
  /// subscription (subscription == null). Required in add mode.
  final void Function(CreateSubscriptionRequest)? onSave;

  /// Called with an UpdateSubscriptionRequest when editing an existing
  /// subscription (subscription != null). Required in edit mode.
  final void Function(UpdateSubscriptionRequest)? onUpdate;

  const AddEditSubscriptionDialog({
    super.key,
    this.subscription,
    this.onSave,
    this.onUpdate,
  }) : assert(
          (subscription == null && onSave != null) ||
              (subscription != null && onUpdate != null),
          'Provide onSave for add mode, or onUpdate for edit mode '
          '(matching whether subscription is null).',
        );

  @override
  State<AddEditSubscriptionDialog> createState() =>
      _AddEditSubscriptionDialogState();
}

class _AddEditSubscriptionDialogState
    extends State<AddEditSubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serviceNameController = TextEditingController();
  final _vendorNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'Streaming';
  String _selectedCurrency = 'USD';
  String _selectedCycle = 'MONTHLY';
  int _usageScore = 5;
  DateTime _nextBillingDate = DateTime.now();
  DateTime _startDate = DateTime.now();

  final List<String> _categories = [
    'Streaming',
    'Music',
    'SaaS Tools',
    'Gaming',
    'Cloud Storage',
    'Security VPN',
    'Utilities',
    'News Reading',
    'AI Tools',
    'Fitness Health',
  ];

  final List<String> _currencies = ['PKR', 'USD', 'EUR', 'GBP'];
  final List<String> _cycles = ['MONTHLY', 'YEARLY', 'QUARTERLY', 'WEEKLY'];

  bool get _isEdit => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    if (widget.subscription != null) {
      final sub = widget.subscription!;
      _serviceNameController.text = sub.serviceName;
      _vendorNameController.text = sub.vendorName ?? '';
      _amountController.text = sub.billingAmount.toString();
      _selectedCategory = sub.categoryName;
      _selectedCurrency = sub.currencyCode;
      _selectedCycle = sub.billingCycle;
      _usageScore = sub.usageScore;
      _nextBillingDate = sub.nextBillingDate;
      _startDate = sub.startDate;
      _notesController.text = sub.notes ?? '';
    } else {
      _nextBillingDate = DateTime.now().add(const Duration(days: 15));
      _startDate = DateTime.now().subtract(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    _vendorNameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCards),
      ),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCards),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _serviceNameController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Service Name',
                          hintText: 'Netflix Premium',
                          prefixIcon: Icon(Icons.subscriptions_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter service name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _vendorNameController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Vendor Name (Optional)',
                          hintText: 'Netflix, Spotify, etc.',
                          prefixIcon: Icon(Icons.business_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        dropdownColor: AppTheme.bgSurface,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: _categories
                            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedCategory = value!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: const InputDecoration(
                                labelText: 'Billing Amount',
                                hintText: '15.99',
                                prefixIcon: Icon(Icons.attach_money_rounded),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCurrency,
                              dropdownColor: AppTheme.bgSurface,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: const InputDecoration(labelText: 'Currency'),
                              items: _currencies
                                  .map((curr) => DropdownMenuItem(value: curr, child: Text(curr)))
                                  .toList(),
                              onChanged: (value) => setState(() => _selectedCurrency = value!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCycle,
                        dropdownColor: AppTheme.bgSurface,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Billing Cycle',
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                        items: _cycles
                            .map((cycle) => DropdownMenuItem(value: cycle, child: Text(cycle)))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedCycle = value!),
                      ),
                      const SizedBox(height: 16),
                      _buildDatePicker(
                        label: 'Start Date',
                        value: _startDate,
                        onChanged: (date) => setState(() => _startDate = date),
                      ),
                      const SizedBox(height: 16),
                      _buildDatePicker(
                        label: 'Next Billing Date',
                        value: _nextBillingDate,
                        onChanged: (date) => setState(() => _nextBillingDate = date),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Usage Score',
                                style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '$_usageScore / 10',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _getUsageColor(),
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            ),
                            child: Slider(
                              value: _usageScore.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              activeColor: _getUsageColor(),
                              inactiveColor: AppTheme.borderColor,
                              onChanged: (value) => setState(() => _usageScore = value.toInt()),
                            ),
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Low Usage', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              Text('High Usage', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'Add any additional notes',
                          prefixIcon: Icon(Icons.note_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandBlue, AppTheme.brandIndigo],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _isEdit ? 'Edit Subscription' : 'Add Subscription',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          HoverIconBadge(
            icon: Icons.close_rounded,
            glowColor: Colors.white,
            size: 32,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: HoverButton(
              label: 'CANCEL',
              outlined: true,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: HoverButton(
              label: _isEdit ? 'UPDATE' : 'SAVE',
              icon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime value,
    required Function(DateTime) onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusInputs),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            // BUG FIX: this previously used ThemeData.dark() as the base
            // with only `primary`/`surface` overridden — every other
            // color (onSurface for day numbers, onPrimary for the
            // selected-day text, header text, etc.) fell back to
            // ThemeData.dark()'s defaults, which are near-white. Against
            // AURIXA's light surfaces that's white-on-white: invisible.
            // Fixed by basing this on ThemeData.light() (matching the
            // app's actual theme everywhere else) with a FULLY specified
            // ColorScheme.light — every text-bearing color explicit, none
            // left to inherited defaults.
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppTheme.brandBlue,
                  onPrimary: Colors.white,
                  primaryContainer: AppTheme.brandBlue,
                  onPrimaryContainer: Colors.white,
                  secondary: AppTheme.brandIndigo,
                  onSecondary: Colors.white,
                  surface: AppTheme.bgSurface,
                  onSurface: AppTheme.textPrimary,
                  surfaceContainerHighest: AppTheme.bgElevated,
                  onSurfaceVariant: AppTheme.textSecondary,
                  outline: AppTheme.borderColor,
                  error: AppTheme.danger,
                  onError: Colors.white,
                ),
                textTheme: ThemeData.light().textTheme.apply(
                      bodyColor: AppTheme.textPrimary,
                      displayColor: AppTheme.textPrimary,
                    ),
                dialogTheme: const DialogThemeData(
                  backgroundColor: AppTheme.bgSurface,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) onChanged(date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(AppTheme.radiusInputs),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label: ${value.day}/${value.month}/${value.year}',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Color _getUsageColor() {
    if (_usageScore >= 8) return AppTheme.success;
    if (_usageScore >= 5) return AppTheme.primary;
    if (_usageScore >= 3) return AppTheme.warning;
    return AppTheme.danger;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final vendorName = _vendorNameController.text.trim().isEmpty
        ? null
        : _vendorNameController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final amount = double.parse(_amountController.text);
    final serviceName = _serviceNameController.text.trim();

    if (_isEdit) {
      // BUG FIX: build the UpdateSubscriptionRequest the notifier actually
      // expects, instead of a CreateSubscriptionRequest. All fields are
      // sent (not just changed ones) since the form always has a full,
      // valid snapshot of every field — simpler and avoids partial-state
      // bugs from tracking individual dirty fields.
      final request = UpdateSubscriptionRequest(
        vendorName: vendorName,
        categoryName: _selectedCategory,
        serviceName: serviceName,
        billingAmount: amount,
        billingCycle: _selectedCycle,
        nextBillingDate: _nextBillingDate,
        usageScore: _usageScore,
        notes: notes,
      );
      widget.onUpdate!(request);
    } else {
      final request = CreateSubscriptionRequest(
        vendorName: vendorName,
        categoryName: _selectedCategory,
        serviceName: serviceName,
        billingAmount: amount,
        billingCycle: _selectedCycle,
        nextBillingDate: _nextBillingDate,
        startDate: _startDate,
        currencyCode: _selectedCurrency,
        usageScore: _usageScore,
        notes: notes,
      );
      widget.onSave!(request);
    }

    Navigator.pop(context);
  }
}