/// VelocityEngine Screen — Full Budget Forecast
/// Content only — Sidebar (and the app's only Scaffold) lives in
/// AppShell, matching the convention established by Dashboard, SubVault,
/// and BehaviorLens.
///
/// Phase 5 rebuild:
///   - Removed the screen's own Scaffold/AppBar.
///   - Gradient hero header (VelocityEngine module color = brandIndigo)
///     with a refresh action built directly into it, matching the
///     header vocabulary used by SubVault/BehaviorLens.
///   - BudgetGauge, VelocityChart, ForecastSummary all rebuilt on
///     HoverCard with module-accent styling instead of plain Material
///     Cards.
///   - Entrance-stagger via HoverEntrance, same as every other phase.
///   - VelocityChart gets the simulated-3D treatment (see its own file
///     header) — gradient-filled area under the historical line, glow
///     "today" marker, animated draw-in. Checked the same fl_chart
///     version-safety question raised for BehaviorLens before touching
///     anything: LineChartBarData.gradient (for a multi-color line
///     stroke) was NOT used here for that reason — see velocity_chart.dart
///     header for what was actually verified safe on ^0.68.0 and used
///     instead (BarAreaData.gradient, which is unrelated to the pie-only
///     property that bit the donut chart, and predates 0.68.0).
///   - Carried forward: the ternary `List<FlSpot>` type-inference fix
///     already documented in velocity_chart.dart — not reintroduced.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../providers/forecast_provider.dart';
import 'widgets/budget_gauge.dart';
import 'widgets/velocity_chart.dart';
import 'widgets/forecast_summary.dart';

class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(forecastProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(forecastProvider);

    return asyncState.when(
      loading: () => const _ForecastLoading(),
      error: (error, _) => _ForecastError(
        message: error.toString(),
        onRetry: _refresh,
      ),
      data: (state) {
        if (state.hasError) {
          return _ForecastError(
            message: state.errorMessage ?? 'Failed to load forecast',
            onRetry: _refresh,
          );
        }

        return RefreshIndicator(
          color: AppTheme.velocityEngine,
          backgroundColor: AppTheme.bgSurface,
          onRefresh: () async => _refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HoverEntrance(
                  index: 0,
                  child: _VelocityEngineHeader(onRefresh: _refresh),
                ),
                const SizedBox(height: 20),

                if (state.forecast == null)
                  HoverEntrance(
                    index: 1,
                    child: const _NoForecastState(),
                  )
                else ...[
                  HoverEntrance(
                    index: 1,
                    child: BudgetGauge(forecast: state.forecast),
                  ),
                  const SizedBox(height: 20),

                  HoverEntrance(
                    index: 2,
                    child: VelocityChart(forecast: state.forecast),
                  ),
                  const SizedBox(height: 20),

                  HoverEntrance(
                    index: 3,
                    child: ForecastSummary(forecast: state.forecast),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _refresh() {
    ref.read(forecastProvider.notifier).refresh();
  }
}

// ============================================================================
// Header — gradient hero band with title + refresh action. Same
// vocabulary as BehaviorLens's header, module color swapped to
// AppTheme.velocityEngine (brandIndigo).
// ============================================================================
class _VelocityEngineHeader extends StatelessWidget {
  const _VelocityEngineHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.velocityEngine, AppTheme.brandBlue],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCards),
        boxShadow: [
          BoxShadow(
            color: AppTheme.velocityEngine.withValues(alpha: 0.3),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;

          final titleBlock = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VelocityEngine',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track your spending pace against budget',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          );

          final refreshButton = _HeaderIconButton(
            icon: Icons.refresh_rounded,
            onTap: onRefresh,
            tooltip: 'Refresh',
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: refreshButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleBlock),
              refreshButton,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovering ? 1.10 : 1.0,
            duration: AppTheme.hoverDuration,
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: AppTheme.hoverDuration,
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _hovering ? 0.26 : 0.16),
                shape: BoxShape.circle,
                boxShadow: _hovering
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ]
                    : [],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// No-forecast empty state — tall/text-heavy → scaleEnabled: false, border
// + glow only, per the shape-first hover rule.
// ============================================================================
class _NoForecastState extends StatelessWidget {
  const _NoForecastState();

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      glowColor: AppTheme.velocityEngine,
      scaleEnabled: false,
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.velocityEngine.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 36,
                color: AppTheme.velocityEngine,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No forecast data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add subscriptions to see your budget forecast',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Loading / Error states — same vocabulary as BehaviorLens.
// ============================================================================
class _ForecastLoading extends StatelessWidget {
  const _ForecastLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(
          strokeWidth: 3.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.velocityEngine),
        ),
      ),
    );
  }
}

class _ForecastError extends StatelessWidget {
  const _ForecastError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 32, color: AppTheme.danger),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            HoverButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}