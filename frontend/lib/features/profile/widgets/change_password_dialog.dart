/// Change Password Dialog — Modal form for secure password change
///
/// Token remap: AppTheme.primary → AppTheme.profileAccent throughout.
/// Each password field gets its own GlowFocusField wrap (focus-reactive
/// gradient border), matching the "actively being typed into" treatment
/// established for SubVault's search field. This is a Dialog, not a
/// ListView item, so owning three FocusNodes here is safe — GlowFocusField
/// itself is the thing that owns the continuously-cycling controller, and
/// it's already self-contained per its own class doc in hover_widgets.dart.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';

class ChangePasswordDialog extends StatefulWidget {
  final Future<String?> Function({
    required String currentPassword,
    required String newPassword,
  }) onChangePassword;

  const ChangePasswordDialog({super.key, required this.onChangePassword});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _currentFocusNode = FocusNode();
  final _newFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _currentFocusNode.dispose();
    _newFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.profileAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: AppTheme.profileAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        color: AppTheme.textSecondary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
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
                            fontSize: 13,
                            color: AppTheme.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Current password
              _buildPasswordField(
                focusNode: _currentFocusNode,
                controller: _currentCtrl,
                label: 'Current Password',
                showPassword: _showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // New password
              _buildPasswordField(
                focusNode: _newFocusNode,
                controller: _newCtrl,
                label: 'New Password',
                showPassword: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 8) return 'Minimum 8 characters';
                  if (v == _currentCtrl.text) {
                    return 'New password must be different';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Confirm password
              _buildPasswordField(
                focusNode: _confirmFocusNode,
                controller: _confirmCtrl,
                label: 'Confirm New Password',
                showPassword: _showConfirm,
                onToggle: () => setState(() => _showConfirm = !_showConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Password strength hint
              _buildStrengthHint(),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HoverButton(
                      label: 'Change Password',
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
    );
  }

  Widget _buildPasswordField({
    required FocusNode focusNode,
    required TextEditingController controller,
    required String label,
    required bool showPassword,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return GlowFocusField(
      focusNode: focusNode,
      borderRadius: 10,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: !showPassword,
        validator: validator,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          // GlowFocusField already owns an opaque bgElevated background —
          // disable the global theme fill so it doesn't compete.
          filled: false,
          labelStyle:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          prefixIcon: const Icon(Icons.lock_outline,
              size: 18, color: AppTheme.textSecondary),
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(
              showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildStrengthHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          _hintRow('At least 8 characters'),
          _hintRow('Must be different from current password'),
          _hintRow('Both passwords must match'),
        ],
      ),
    );
  }

  Widget _hintRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 5, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await widget.onChangePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      Navigator.of(context).pop(true); // success
    } else {
      setState(() => _errorMessage = error);
    }
  }
}