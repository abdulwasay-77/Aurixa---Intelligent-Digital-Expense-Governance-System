/// AURIXA Splash Screen — "Light Sweep Reveal"
///
/// Sequence:
///   1. Window opens small (560×440), centered, chrome-less.
///   2. Diagonal sweep fires across the dark frame.
///   3. AURIXA wordmark sharpens into focus out of a blur.
///   4. Gradient underline draws in beneath the wordmark.
///   5. Tagline fades in: "YOUR SPENDING, DECODED".
///   6. Shimmer + spinning ring loop during idle wait.
///   7. After ~3.8s: window widens smoothly to 920×440, staying centered,
///      then navigates to /login.
///
/// The widen animation uses a Ticker (frame-synced, never delayed) instead
/// of an async loop with Future.delayed — this is what eliminates the
/// shaking. Each step fires exactly once per display frame at 60fps.
library;

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _sweepDelay          = Duration(milliseconds: 200);
  static const _sweepDuration       = Duration(milliseconds: 900);
  static const _logoRevealDelay     = Duration(milliseconds: 650);
  static const _logoRevealDuration  = Duration(milliseconds: 700);
  static const _underlineDelay      = Duration(milliseconds: 1250);
  static const _underlineDuration   = Duration(milliseconds: 500);
  static const _taglineDelay        = Duration(milliseconds: 1500);
  static const _taglineDuration     = Duration(milliseconds: 500);
  static const _idleEffectsDelay    = Duration(milliseconds: 1700);
  static const _totalSplashDuration = Duration(milliseconds: 3800);

  // How long the window-widen animation takes.
  static const _widenDuration = Duration(milliseconds: 450);

  late final AnimationController _sweepController;
  late final AnimationController _logoController;
  late final AnimationController _underlineController;
  late final AnimationController _taglineController;
  late final AnimationController _shimmerController;
  late final AnimationController _spinController;

  bool _idleEffectsStarted = false;
  Timer? _navTimer;
  Ticker? _widenTicker;

  @override
  void initState() {
    super.initState();

    _sweepController     = AnimationController(vsync: this, duration: _sweepDuration);
    _logoController      = AnimationController(vsync: this, duration: _logoRevealDuration);
    _underlineController = AnimationController(vsync: this, duration: _underlineDuration);
    _taglineController   = AnimationController(vsync: this, duration: _taglineDuration);
    _shimmerController   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _spinController      = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _runSequence();
  }

  Future<void> _runSequence() async {
    Future.delayed(_sweepDelay,       () { if (mounted) _sweepController.forward(); });
    Future.delayed(_logoRevealDelay,  () { if (mounted) _logoController.forward(); });
    Future.delayed(_underlineDelay,   () { if (mounted) _underlineController.forward(); });
    Future.delayed(_taglineDelay,     () { if (mounted) _taglineController.forward(); });
    Future.delayed(_idleEffectsDelay, () {
      if (!mounted) return;
      setState(() => _idleEffectsStarted = true);
      _shimmerController.repeat();
      _spinController.repeat();
    });

    _navTimer = Timer(_totalSplashDuration, _transitionToLogin);
  }

  Future<void> _transitionToLogin() async {
    if (!mounted) return;

    // Read screen size once before the animation starts.
    final display     = ui.PlatformDispatcher.instance.displays.firstOrNull;
    final screenW     = display != null ? display.size.width  / display.devicePixelRatio : 1920.0;
    final screenH     = display != null ? display.size.height / display.devicePixelRatio : 1080.0;

    const fromW = AppTheme.splashWindowWidth;
    const toW   = AppTheme.authWindowWidth;
    const h     = AppTheme.authWindowHeight;
    final totalMs = _widenDuration.inMilliseconds.toDouble();

    // Use a Completer so we can await the ticker finishing.
    final completer = Completer<void>();

    Duration? startTime;

    _widenTicker = createTicker((elapsed) {
      startTime ??= elapsed;
      final t = ((elapsed - startTime!).inMilliseconds / totalMs).clamp(0.0, 1.0);

      // Ease-out cubic: fast start, smooth deceleration into final size.
      final eased = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
      final width = fromW + (toW - fromW) * eased;
      final x     = (screenW - width) / 2;
      final y     = (screenH - h) / 2;

      // Fire and forget — we do NOT await here. The ticker fires every
      // frame; we just send the new bounds and move on. Windows queues
      // these natively and renders them in order, giving smooth motion.
      windowManager.setBounds(Rect.fromLTWH(x, y, width, h));

      if (t >= 1.0) {
        _widenTicker?.stop();
        completer.complete();
      }
    });

    _widenTicker!.start();
    await completer.future;

    if (!mounted) return;
    context.go(AppConstants.routeLogin);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _widenTicker?.dispose();
    _sweepController.dispose();
    _logoController.dispose();
    _underlineController.dispose();
    _taglineController.dispose();
    _shimmerController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  ui.ImageFilter _blurFilter(double sigma) {
    final s = sigma.clamp(0.0, 8.0);
    return ui.ImageFilter.blur(sigmaX: s, sigmaY: s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
            // ── Diagonal light sweep ──────────────────────────────────
            AnimatedBuilder(
              animation: _sweepController,
              builder: (context, child) => CustomPaint(
                size: Size.infinite,
                painter: SweepPainter(progress: _sweepController.value),
              ),
            ),

            // ── Logo + underline + tagline + spinner ──────────────────
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_logoController.value);
                    return Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 1.08 - (0.08 * t),
                        child: ImageFiltered(
                          imageFilter: _blurFilter(8 * (1 - t)),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: const LogoWordmark(fontSize: 52),
                ),
                const SizedBox(height: 14),

                AnimatedBuilder(
                  animation: Listenable.merge([_underlineController, _shimmerController]),
                  builder: (context, child) => UnderlineBar(
                    drawProgress: Curves.easeOutCubic.transform(_underlineController.value),
                    shimmerProgress: _idleEffectsStarted ? _shimmerController.value : 0,
                    width: 220,
                  ),
                ),
                const SizedBox(height: 16),

                FadeTransition(
                  opacity: _taglineController,
                  child: const Text(
                    'YOUR SPENDING, DECODED',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8B8FC0),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                AnimatedOpacity(
                  opacity: _idleEffectsStarted ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: AnimatedBuilder(
                    animation: _spinController,
                    builder: (context, child) => Transform.rotate(
                      angle: _spinController.value * 6.28319,
                      child: child,
                    ),
                    child: const GradientSpinnerRing(size: 22),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LogoWordmark
// ============================================================================
class LogoWordmark extends StatelessWidget {
  const LogoWordmark({super.key, required this.fontSize});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Colors.white,
        ),
        children: [
          const TextSpan(text: 'AURI'),
          TextSpan(
            text: 'X',
            style: TextStyle(
              foreground: Paint()
                ..shader = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.brandBlue, AppTheme.brandPurple],
                ).createShader(Rect.fromLTWH(0, 0, fontSize * 0.7, fontSize)),
            ),
          ),
          const TextSpan(text: 'A'),
        ],
      ),
    );
  }
}

// ============================================================================
// UnderlineBar
// ============================================================================
class UnderlineBar extends StatelessWidget {
  const UnderlineBar({
    super.key,
    required this.drawProgress,
    required this.shimmerProgress,
    required this.width,
  });

  final double drawProgress;
  final double shimmerProgress;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: drawProgress,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.brandBlue, AppTheme.brandPurple],
                    ),
                  ),
                ),
              ),
            ),
            if (drawProgress >= 0.99 && shimmerProgress > 0)
              FractionalTranslation(
                translation: Offset(-1.5 + (3.0 * shimmerProgress), 0),
                child: FractionallySizedBox(
                  widthFactor: 0.4,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.85),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GradientSpinnerRing
// ============================================================================
class GradientSpinnerRing extends StatelessWidget {
  const GradientSpinnerRing({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: SpinnerRingPainter()),
    );
  }
}

class SpinnerRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          AppTheme.brandBlue,
          AppTheme.brandIndigo,
          AppTheme.brandPurple,
          Colors.transparent,
        ],
        stops: [0.0, 0.4, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect.deflate(1.25), 0, 5.0, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// SweepPainter
// ============================================================================
class SweepPainter extends CustomPainter {
  SweepPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final eased     = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    final travel    = size.width * 2.6;
    final centerX   = -size.width * 1.3 + travel * eased;
    final bandWidth = size.width * 0.5;
    final rect = Rect.fromLTWH(centerX - bandWidth / 2, 0, bandWidth, size.height);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          AppTheme.brandPurple.withValues(alpha: 0.30),
          AppTheme.brandBlue.withValues(alpha: 0.40),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.plus;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(0.17);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(rect.inflate(size.height), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}