/// AURIXA Register Screen
///
/// Same split-panel treatment as login_screen.dart — static brand panel
/// on the left (no animation replay needed here since the user arrived
/// via in-app navigation, not a fresh window), full registration form on
/// the right restyled with the new theme + hover widgets.
///
/// IMPORTANT: every field, validator, and the RegisterRequest payload
/// shape are UNCHANGED from the previous implementation — this preserves
/// the existing backend contract (full name, email, phone, password,
/// confirm password, monthly income, saving target slider, risk
/// tolerance dropdown, base currency dropdown). Only presentation layer
/// is new.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_provider.dart';
import 'splash_screen.dart' show LogoWordmark, UnderlineBar;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _incomeController = TextEditingController();

  double _savingTarget = 20.0;
  String _riskTolerance = 'MEDIUM';
  String _baseCurrency = 'USD';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final List<String> _riskOptions = ['LOW', 'MEDIUM', 'HIGH'];
  final List<String> _currencyOptions = ['PKR', 'USD', 'EUR', 'GBP'];

  late final AnimationController _formEntryController;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _formFade;

  @override
  void initState() {
    super.initState();
    _formEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _formEntryController, curve: Curves.easeOutCubic),
    );
    _formFade = CurvedAnimation(
      parent: _formEntryController,
      curve: Curves.easeOut,
    );
    _formEntryController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _incomeController.dispose();
    _formEntryController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Parse and validate monthly income
    double? monthlyIncome;
    try {
      monthlyIncome = double.parse(_incomeController.text.trim());
      if (monthlyIncome <= 0) {
        _showError('Monthly income must be greater than 0');
        return;
      }
      if (monthlyIncome > 999999) {
        _showError('Monthly income is too high');
        return;
      }
    } catch (e) {
      _showError('Please enter a valid monthly income amount');
      return;
    }

    setState(() => _isLoading = true);

    final request = RegisterRequest(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      monthlyIncome: monthlyIncome,
      savingTargetPct: _savingTarget,
      riskTolerance: _riskTolerance,
      lifestyleCategory: null,
      baseCurrencyCode: _baseCurrency,
    );

    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.register(request);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success && mounted) {
      context.go(AppConstants.routeDashboard);
    } else if (mounted) {
      final error = ref.read(authProvider).error;
      _showError(error ?? 'Registration failed. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── LEFT: static brand panel ─────────────────────────────────
          Expanded(
            flex: 38,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.splashBgStart, AppTheme.splashBgEnd],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoWordmark(fontSize: 30),
                    const SizedBox(height: 10),
                    const UnderlineBar(
                      drawProgress: 1.0,
                      shimmerProgress: 0,
                      width: 130,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'YOUR SPENDING, DECODED',
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8B8FC0),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'Set up your profile once — AURIXA tunes its '
                        'forecasts and risk alerts to your income and '
                        'goals from day one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── RIGHT: registration form ──────────────────────────────────
          Expanded(
            flex: 62,
            child: Container(
              color: AppTheme.bgSurface,
              child: SlideTransition(
                position: _formSlide,
                child: FadeTransition(
                  opacity: _formFade,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Title
                            const Text(
                              'Create account',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Join AURIXA to take control of your finances',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Full Name
                            TextFormField(
                              controller: _fullNameController,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                hintText: 'John Doe',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your full name';
                                }
                                if (value.length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                hintText: 'you@example.com',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@') ||
                                    !value.contains('.')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Phone (Optional)
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Phone number (optional)',
                                hintText: '0312 1234567',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Confirm Password
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Confirm password',
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirm = !_obscureConfirm;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Monthly Income
                            TextFormField(
                              controller: _incomeController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Monthly income (USD)',
                                hintText: '5000',
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your monthly income';
                                }
                                final parsed = double.tryParse(value);
                                if (parsed == null) {
                                  return 'Please enter a valid number';
                                }
                                if (parsed <= 0) {
                                  return 'Income must be greater than 0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Saving Target Slider
                            Text(
                              'Saving target: ${_savingTarget.toInt()}%',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppTheme.brandBlue,
                                inactiveTrackColor: AppTheme.borderColor,
                                thumbColor: AppTheme.brandPurple,
                                overlayColor:
                                    AppTheme.brandPurple.withValues(alpha: 0.18),
                              ),
                              child: Slider(
                                value: _savingTarget,
                                min: 0,
                                max: 100,
                                divisions: 20,
                                onChanged: (value) {
                                  setState(() {
                                    _savingTarget = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Risk Tolerance Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _riskTolerance,
                              dropdownColor: AppTheme.bgElevated,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Risk tolerance',
                                prefixIcon: Icon(Icons.trending_up),
                              ),
                              items: _riskOptions.map((option) {
                                return DropdownMenuItem(
                                  value: option,
                                  child: Text(option),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _riskTolerance = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 14),

                            // Base Currency Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _baseCurrency,
                              dropdownColor: AppTheme.bgElevated,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Base currency',
                                prefixIcon: Icon(Icons.currency_exchange),
                              ),
                              items: _currencyOptions.map((option) {
                                return DropdownMenuItem(
                                  value: option,
                                  child: Text(option),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _baseCurrency = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 26),

                            // Register Button
                            HoverButton(
                              label: 'Create account',
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : _handleRegister,
                            ),
                            const SizedBox(height: 18),

                            // Login Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                HoverTextLink(
                                  text: 'Sign in',
                                  onTap: () => context.pop(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}