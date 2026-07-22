/// AURIXA Login Screen
///
/// Layout: split panel inside the widened (920x440) chrome-less window.
///   - LEFT (38%): dark brand panel. On first build, replays the SAME
///     light-sweep-reveal animation from the splash screen, scaled down,
///     settling into a static logo + tagline once finished (per spec —
///     "same sweep-reveal treatment, scaled down, in the left brand
///     panel").
///   - RIGHT (62%): light surface, login form. Slides in from the right
///     on entry (matches the prototype's slideInLogin animation), uses
///     the new AppTheme.bgSurface fields and HoverButton/HoverTextLink
///     primitives so every interactive element gets the standard
///     zoom+glow hover treatment.
///
/// Auth logic (authProvider.login, error handling, navigation target) is
/// UNCHANGED from the previous implementation — only presentation layer
/// is new.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../providers/auth_provider.dart';
import 'splash_screen.dart' show LogoWordmark, UnderlineBar, SweepPainter;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Brand panel sweep replay — same mechanics as splash, smaller scale,
  // settles to static once done (no looping shimmer/spinner here; this
  // panel's job is just to land, not to keep asking the user to wait).
  late final AnimationController _sweepController;
  late final AnimationController _logoController;
  late final AnimationController _underlineController;

  // Right panel slide-in.
  late final AnimationController _formEntryController;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _formFade;

  @override
  void initState() {
    super.initState();

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _underlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _formEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _formEntryController, curve: Curves.easeOutCubic),
    );
    _formFade = CurvedAnimation(
      parent: _formEntryController,
      curve: Curves.easeOut,
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _sweepController.forward();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _logoController.forward();
    });
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _underlineController.forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _formEntryController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _sweepController.dispose();
    _logoController.dispose();
    _underlineController.dispose();
    _formEntryController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success && mounted) {
      context.go(AppConstants.routeDashboard);
    } else if (mounted) {
      final error = ref.read(authProvider).error;
      _showError(error ?? 'Login failed. Please check your credentials.');
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
          // ── LEFT: brand panel, replays scaled sweep-reveal ──────────
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _sweepController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size.infinite,
                        painter: SweepPainter(progress: _sweepController.value),
                      );
                    },
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          final t = Curves.easeOutCubic.transform(
                            _logoController.value,
                          );
                          return Opacity(
                            opacity: t,
                            child: Transform.scale(
                              scale: 1.05 - (0.05 * t),
                              child: child,
                            ),
                          );
                        },
                        child: const LogoWordmark(fontSize: 30),
                      ),
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: _underlineController,
                        builder: (context, child) {
                          return UnderlineBar(
                            drawProgress: Curves.easeOutCubic.transform(
                              _underlineController.value,
                            ),
                            shimmerProgress: 0, // settled — no loop here
                            width: 130,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _logoController,
                        child: const Text(
                          'YOUR SPENDING, DECODED',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8B8FC0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── RIGHT: login form, slides in from the right ─────────────
          Expanded(
            flex: 62,
            child: Container(
              color: AppTheme.bgSurface,
              child: Center(
                child: SlideTransition(
                  position: _formSlide,
                  child: FadeTransition(
                    opacity: _formFade,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Welcome back',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Sign in to continue to your dashboard',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Email Field
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
                              const SizedBox(height: 16),

                              // Password Field
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
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _handleLogin(),
                              ),
                              const SizedBox(height: 24),

                              // Sign in — gradient hover button
                              HoverButton(
                                label: 'Sign in',
                                isLoading: _isLoading,
                                onPressed: _isLoading ? null : _handleLogin,
                              ),
                              const SizedBox(height: 18),

                              // Register Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  HoverTextLink(
                                    text: 'Create account',
                                    onTap: () {
                                      context.push(AppConstants.routeRegister);
                                    },
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
          ),
        ],
      ),
    );
  }
}