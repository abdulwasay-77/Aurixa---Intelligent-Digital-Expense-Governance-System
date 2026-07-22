/// ScoreHistory Screen — Phase 8 — Full Nebula Enhancement
///
/// Starts from legacy baseline (plain Card widgets, generic AppBar,
/// AppTheme.bgCanvas / AppTheme.primary references that no longer exist
/// in the locked palette). This file is a complete ground-up replacement:
///
///   - Token remap: bgCanvas → bgBase, primary → scoreCore throughout.
///   - AppBar removed — AppShell owns chrome; this file is content only.
///   - Gradient hero header matching Phase 3-7 vocabulary
///     (scoreCore #3DCB8F → brandIndigo #7B5CE8).
///   - HoverEntrance cascade on every major section.
///   - _CurrentScoreSummary converted from plain Card → HoverCard with
///     animated score ring in its own StatefulWidget + RepaintBoundary
///     (Lesson 7 — continuously-ticking AnimationController never owned
///     by a widget that is a ListView ancestor; correctly self-contained
///     even though it isn't in a ListView, because the ring controller
///     runs until dispose and would still cause frame-budget churn if
///     owned by the screen StatefulWidget which rebuilds on provider
///     changes).
///   - Lesson 10 proactive: every HoverEntrance call site has Expanded
///     on the OUTSIDE, never as a direct child of HoverEntrance.
///   - Lesson 11 proactive: _isRefreshing is a local bool on State,
///     not derived from asyncState.value?.anything.
///   - Refresh button uses a RotationTransition spin controller owned
///     here (not inside a ListView item — Lesson 7 safe).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../models/analytics_models.dart';
import '../../providers/score_history_provider.dart';
import 'widgets/score_trend_chart.dart';
import 'widgets/sub_score_bars.dart';

class ScoreHistoryScreen extends ConsumerStatefulWidget {
  const ScoreHistoryScreen({super.key});

  @override
  ConsumerState<ScoreHistoryScreen> createState() => _ScoreHistoryScreenState();
}

class _ScoreHistoryScreenState extends ConsumerState<ScoreHistoryScreen>
    with SingleTickerProviderStateMixin {
  // Lesson 11 — local bool, never derived from asyncState.value?.isLoading
  bool _isRefreshing = false;

  // Spin controller for the refresh icon in the hero header.
  // Safe here: the screen widget is NOT a ListView child, so this
  // continuously-ticking controller doesn't violate Lesson 7. The ring
  // controller inside _AnimatedScoreRing is still isolated there because
  // that widget outlives any individual rebuild of this screen.
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scoreHistoryProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    // Lesson 11 — set local flag BEFORE the await; don't rely on provider
    setState(() => _isRefreshing = true);
    _spinController.repeat();
    await ref.read(scoreHistoryProvider.notifier).refresh();
    if (mounted) {
      _spinController.stop();
      _spinController.reset();
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(scoreHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Gradient hero header (matches Phase 3–7 vocabulary) ──────────
        _buildHeroHeader(),

        // ── Body ─────────────────────────────────────────────────────────
        Expanded(
          child: asyncState.when(
            loading: _buildLoading,
            error: (e, _) => _buildError(e.toString()),
            data: (state) {
              if (state.hasError) {
                return _buildError(
                  state.errorMessage ?? 'Failed to load score history',
                );
              }
              final hasNoData = state.latestScore == null &&
                  (state.trend == null || state.trend!.trend.isEmpty);
              if (hasNoData) return _buildEmpty();
              return _buildContent(state);
            },
          ),
        ),
      ],
    );
  }

  // ── Hero header ──────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      // Lesson 8 — explicit width: double.infinity so inner Row's
      // Expanded children have a concrete parent width constraint.
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // scoreCore → brandIndigo — same left-to-right gradient family
          // as every module hero since Phase 3.
          colors: [AppTheme.scoreCore, AppTheme.brandIndigo],
        ),
      ),
      child: Row(
        children: [
          // Module icon badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),

          // Title + sub-label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Score History',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Financial health score · trend · sub-score breakdown',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Glass refresh button with spinning icon
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return GestureDetector(
      onTap: _isRefreshing ? null : _refresh,
      child: MouseRegion(
        cursor: _isRefreshing
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusButtons),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _spinController,
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Refresh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── States ───────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        // scoreCore replaces the old AppTheme.primary reference
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.scoreCore),
      ),
    );
  }

  Widget _buildError(String message) {
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
                color: AppTheme.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppTheme.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              child: HoverButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: _refresh,
                expand: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.scoreCore.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              size: 36,
              color: AppTheme.scoreCore,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No score history yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your financial health score will appear here\nonce it has been calculated.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Main content ─────────────────────────────────────────────────────────
  Widget _buildContent(ScoreHistoryState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Lesson 10 — Expanded wraps HoverEntrance, never the reverse.
          // (Not in a Row here so Expanded isn't needed, but the pattern
          // is: if this ever went into a Row, put Expanded on the outside.)

          // 0 — Current score hero card
          HoverEntrance(
            index: 0,
            child: _CurrentScoreSummary(score: state.latestScore),
          ),
          const SizedBox(height: 20),

          // 1 — 6-month trend line chart
          HoverEntrance(
            index: 1,
            child: ScoreTrendChart(trend: state.trend),
          ),
          const SizedBox(height: 20),

          // 2 — Sub-score breakdown bars
          HoverEntrance(
            index: 2,
            child: SubScoreBars(score: state.latestScore),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _CurrentScoreSummary
//
// Shape classification: isolated hero card, NOT in a dense row.
// Hover tier: scaleEnabled: false — the card hosts a continuously-ticking
// AnimationController (_AnimatedScoreRing). Zooming the container while
// an animated child is running causes double-transform churn that reads
// as jitter. Glow-only treatment is correct here (same reasoning as any
// tall/animated card).
// ============================================================================

class _CurrentScoreSummary extends StatelessWidget {
  final FinancialScoreResponse? score;

  const _CurrentScoreSummary({this.score});

  @override
  Widget build(BuildContext context) {
    final healthScore = score?.financialHealthScore ?? 0;
    final label = score?.scoreLabel ?? 'NOT_CALCULATED';
    final statusColor = _labelColor(label, healthScore);
    final scoreDate = score?.scoreDate;

    return HoverCard(
      glowColor: AppTheme.scoreCore,
      // scaleEnabled: false — card contains a live AnimationController
      // inside _AnimatedScoreRing. See class doc above.
      scaleEnabled: false,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated score ring — self-contained StatefulWidget so its
          // AnimationController is owned in its own lifecycle (Lesson 7).
          // RepaintBoundary stops the ring's per-frame paints from
          // invalidating the text and badge siblings.
          RepaintBoundary(
            child: _AnimatedScoreRing(
              score: healthScore,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 24),

          // Label, gauge bar, and date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Current Financial Health',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Status label badge
                _StatusBadge(label: label, color: statusColor),

                const SizedBox(height: 14),

                // Thin gauge bar — gives a second visual read of the
                // numeric score without repeating the number.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${healthScore.toStringAsFixed(1)} / 100',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(healthScore).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (healthScore / 100).clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: AppTheme.borderColor,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ],
                ),

                if (scoreDate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'As of ${_formatDate(scoreDate)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _labelColor(String label, double fallbackScore) {
    switch (label.toUpperCase()) {
      case 'EXCELLENT':
        return AppTheme.success;
      case 'GOOD':
        // scoreCore replaces the old AppTheme.primary reference
        return AppTheme.scoreCore;
      case 'FAIR':
        return AppTheme.warning;
      case 'POOR':
      case 'CRITICAL':
        return AppTheme.danger;
      default:
        if (fallbackScore >= 80) return AppTheme.success;
        if (fallbackScore >= 60) return AppTheme.scoreCore;
        if (fallbackScore >= 40) return AppTheme.warning;
        return AppTheme.danger;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  static IconData _icon(String label) {
    switch (label.toUpperCase()) {
      case 'EXCELLENT':
        return Icons.star_rounded;
      case 'GOOD':
        return Icons.thumb_up_rounded;
      case 'FAIR':
        return Icons.info_rounded;
      case 'POOR':
      case 'CRITICAL':
        return Icons.warning_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  static String _text(String label) {
    if (label == 'NOT_CALCULATED') return 'Not Calculated';
    return label[0].toUpperCase() + label.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusBadges),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(label), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            _text(label),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _AnimatedScoreRing
//
// Self-contained StatefulWidget — owns the ring's AnimationController so
// it never leaks into the parent screen's rebuild cycle (Lesson 7).
// RepaintBoundary applied by the caller so per-frame ring paints don't
// dirty the surrounding text and badge widgets.
// ============================================================================

class _AnimatedScoreRing extends StatefulWidget {
  final double score;
  final Color color;

  const _AnimatedScoreRing({required this.score, required this.color});

  @override
  State<_AnimatedScoreRing> createState() => _AnimatedScoreRingState();
}

class _AnimatedScoreRingState extends State<_AnimatedScoreRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;
  late final Animation<double> _counter;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final curved =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _progress = Tween<double>(
      begin: 0,
      end: (widget.score / 100).clamp(0.0, 1.0),
    ).animate(curved);
    _counter = Tween<double>(begin: 0, end: widget.score).animate(curved);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle colored glow behind the ring — same drop-shadow
              // "puck" vocabulary as the donut chart (see
              // category_donut_chart.dart): a blurred circle below the
              // actual widget, painted using Container + BoxShadow.
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.28),
                      blurRadius: 28,
                      spreadRadius: -4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),

              // Track ring (background)
              SizedBox(
                width: 104,
                height: 104,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.borderColor.withValues(alpha: 0.45),
                  ),
                ),
              ),

              // Progress arc — strokeCap round for a smooth, modern look.
              SizedBox(
                width: 104,
                height: 104,
                child: CircularProgressIndicator(
                  value: _progress.value,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(widget.color),
                ),
              ),

              // Score counter readout in the ring hole
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _counter.value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: widget.color,
                      height: 1,
                    ),
                  ),
                  Text(
                    'pts',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: widget.color.withValues(alpha: 0.65),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}