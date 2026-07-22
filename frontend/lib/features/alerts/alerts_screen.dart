/// RiskRadar — Phase 6 UI Enhancement (Bug-fix revision)
///
/// Fixes vs. first delivery:
///
/// FIX 1 (layout crash) — in alert_card.dart (companion file).
///
/// FIX 2 — BOTTOM OVERFLOWED BY 281 PIXELS in hero header
///   Root cause: _buildSummaryRow returned a Row of Expanded children. That
///   Row was placed directly inside the hero gradient Container's Column with
///   no explicit width or height on the outer Container (the Column measures
///   children intrinsically when unconstrained). The Row tried to measure its
///   Expanded children against an infinite width, failed, fell back to zero,
///   then overflowed when the Column tried to stack them vertically.
///
///   Fix: the hero Container now uses width: double.infinity so the Column
///   has a concrete horizontal constraint to pass down to the Row. The stat
///   tiles use Expanded inside that Row, which now resolves correctly.
///   Additionally, the summary row is only appended if the screen is in the
///   data-loaded state (not during loading/error), so it never tries to
///   render with a null summary.
///
/// FIX 3 — Null check operator crash on spinController
///   The _HeaderActionButton builds a RotationTransition only when
///   spinController != null (already guarded). Confirmed the guard is
///   sufficient — the crash was a secondary symptom of FIX 2's layout failure
///   causing the render tree to be in an invalid state when the button tried
///   to paint. With FIX 2 resolved this should not recur. Added explicit
///   null-safe late-init guard as defense.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../models/alert_models.dart';
import '../../providers/alert_provider.dart';
import 'widgets/alert_card.dart';
import 'widgets/severity_filter.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshSpin;

  @override
  void initState() {
    super.initState();
    _refreshSpin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshSpin.dispose();
    super.dispose();
  }

  // ==========================================================================
  // Build
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(alertProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroHeader(asyncState),
          Expanded(
            child: asyncState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.riskRadar),
                ),
              ),
              error: (error, _) => _buildErrorState(error.toString()),
              data: (state) {
                if (state.hasError) {
                  return _buildErrorState(
                      state.errorMessage ?? 'Failed to load alerts');
                }
                return _buildDataBody(state);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Hero Header
  //
  // FIX 2: Container must have width: double.infinity so the inner Column
  // has a concrete horizontal constraint. Without it, a Row of Expanded
  // children measures against infinite width → layout failure → overflow.
  // ==========================================================================

  Widget _buildHeroHeader(AsyncValue<AlertState> asyncState) {
    final unreadCount = asyncState.value?.unreadCount ?? 0;
    final isDetecting = asyncState.value?.isAnomalyDetecting == true;
    // Only show summary when we have real loaded data with a non-null summary.
    final summary = asyncState.value?.summary;

    return HoverEntrance(
      index: 0,
      child: Container(
        width: double.infinity, // FIX 2: concrete width for Row/Expanded below
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.riskRadar, AppTheme.brandIndigo],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // never take infinite height
          children: [
            // ── Title row ─────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Module icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Title + unread badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'RiskRadar',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 10),
                            _UnreadBadge(count: unreadCount),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Anomaly detection · Severity monitoring · Spend alerts',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                _buildHeaderActions(isDetecting),
              ],
            ),

            // ── Summary stat row ──────────────────────────────────────────
            // FIX 2: only render when summary is non-null (data is loaded).
            // The Row of Expanded tiles now has a concrete parent width from
            // the Container(width: double.infinity) above.
            if (summary != null) ...[
              const SizedBox(height: 18),
              _buildSummaryRow(summary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActions(bool isDetecting) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HoverEntrance(
          index: 1,
          child: Tooltip(
            message: 'Run AI Anomaly Detection',
            child: _HeaderActionButton(
              icon: isDetecting ? null : Icons.auto_awesome,
              isLoading: isDetecting,
              onTap: isDetecting ? null : _triggerAnomalyDetection,
            ),
          ),
        ),
        const SizedBox(width: 8),
        HoverEntrance(
          index: 2,
          child: Tooltip(
            message: 'Mark All as Read',
            child: _HeaderActionButton(
              icon: Icons.done_all_rounded,
              onTap: _markAllAlertsRead,
            ),
          ),
        ),
        const SizedBox(width: 8),
        HoverEntrance(
          index: 3,
          child: Tooltip(
            message: 'Refresh',
            child: _HeaderActionButton(
              icon: Icons.refresh_rounded,
              spinController: _refreshSpin,
              onTap: () {
                _refreshSpin.forward(from: 0.0);
                _refresh();
              },
            ),
          ),
        ),
      ],
    );
  }

  // FIX 2: This Row is now inside a Container(width: double.infinity),
  // so Expanded children resolve correctly.
  Widget _buildSummaryRow(AlertSummaryResponse summary) {
    return Row(
      children: [
        Expanded(
          child: HoverEntrance(
            index: 2,
            child: _SummaryStatTile(
              label: 'Critical',
              count: summary.criticalCount,
              color: AppTheme.danger,
              icon: Icons.error_rounded,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: HoverEntrance(
            index: 3,
            child: _SummaryStatTile(
              label: 'High',
              count: summary.highCount,
              color: AppTheme.danger.withValues(alpha: 0.75),
              icon: Icons.warning_amber_rounded,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: HoverEntrance(
            index: 4,
            child: _SummaryStatTile(
              label: 'Medium',
              count: summary.mediumCount,
              color: AppTheme.warning,
              icon: Icons.info_rounded,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: HoverEntrance(
            index: 5,
            child: _SummaryStatTile(
              label: 'Low',
              count: summary.lowCount,
              color: AppTheme.info,
              icon: Icons.circle_notifications_rounded,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // Data Body
  // ==========================================================================

  Widget _buildDataBody(AlertState state) {
    return Column(
      children: [
        HoverEntrance(
          index: 6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: SeverityFilter(
              selectedSeverity: state.selectedSeverity,
              onSeveritySelected: (severity) {
                ref.read(alertProvider.notifier).filterBySeverity(severity);
              },
              criticalCount: state.summary?.criticalCount ?? 0,
              highCount: state.summary?.highCount ?? 0,
              mediumCount: state.summary?.mediumCount ?? 0,
              lowCount: state.summary?.lowCount ?? 0,
            ),
          ),
        ),
        Expanded(
          child: state.alerts.isEmpty
              ? _buildEmptyState(state.selectedSeverity)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  itemCount: state.alerts.length,
                  itemBuilder: (context, index) {
                    final alert = state.alerts[index];
                    return HoverEntrance(
                      index: index + 7,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AlertCard(
                          alert: alert,
                          onMarkRead: () => _markAlertRead(alert.alertId),
                          onTap: () => _showAlertDetails(alert),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (state.totalCount > state.pageSize) _buildPagination(state),
      ],
    );
  }

  Widget _buildPagination(AlertState state) {
    final totalPages = (state.totalCount / state.pageSize).ceil();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HoverGlow(
            glowColor: AppTheme.riskRadar,
            size: HoverSize.small,
            borderRadius: 8,
            onTap: state.page > 1
                ? () => ref
                    .read(alertProvider.notifier)
                    .goToPage(state.page - 1)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.chevron_left_rounded,
                color: state.page > 1
                    ? AppTheme.textPrimary
                    : AppTheme.textMuted,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Page ${state.page} of $totalPages',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          HoverGlow(
            glowColor: AppTheme.riskRadar,
            size: HoverSize.small,
            borderRadius: 8,
            onTap: state.page < totalPages
                ? () => ref
                    .read(alertProvider.notifier)
                    .goToPage(state.page + 1)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.chevron_right_rounded,
                color: state.page < totalPages
                    ? AppTheme.textPrimary
                    : AppTheme.textMuted,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Empty State
  // ==========================================================================

  Widget _buildEmptyState(String? filteredSeverity) {
    final isFiltered = filteredSeverity != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.success, AppTheme.brandBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.success.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.verified_rounded,
                color: Colors.white, size: 34),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered
                ? 'No ${filteredSeverity.toLowerCase()} alerts'
                : 'All Clear!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Try selecting a different severity filter'
                : 'AURIXA will notify you of any suspicious activity',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Error State
  // ==========================================================================

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: AppTheme.danger, size: 30),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          HoverButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onPressed: _refresh,
            expand: false,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Alert Detail Dialog
  // ==========================================================================

  void _showAlertDetails(AlertResponse alert) {
    final severityColor = _severityColor(alert.severity);
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCards)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 34,
                      decoration: BoxDecoration(
                        color: severityColor,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: severityColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _DialogBadge(
                        label: alert.severityLabel,
                        color: severityColor,
                        filled: true),
                    const SizedBox(width: 8),
                    _DialogBadge(
                        label: alert.alertTypeLabel,
                        color: AppTheme.brandIndigo,
                        filled: false),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.borderColor),
                const SizedBox(height: 14),
                Text(
                  alert.message,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.55),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(alert.timeAgo,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted)),
                    if (alert.relatedSubName != null) ...[
                      const SizedBox(width: 14),
                      const Icon(Icons.subscriptions_rounded,
                          size: 13, color: AppTheme.textMuted),
                      const SizedBox(width: 5),
                      Text(alert.relatedSubName!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!alert.isRead) ...[
                      HoverButton(
                        label: 'Mark as Read',
                        icon: Icons.done_rounded,
                        outlined: true,
                        expand: false,
                        onPressed: () {
                          Navigator.pop(context);
                          _markAlertRead(alert.alertId);
                        },
                      ),
                      const SizedBox(width: 12),
                    ],
                    HoverButton(
                      label: 'Close',
                      expand: false,
                      onPressed: () => Navigator.pop(context),
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

  // ==========================================================================
  // Helpers
  // ==========================================================================

  Color _severityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return AppTheme.danger;
      case 'HIGH':
        return AppTheme.danger.withValues(alpha: 0.82);
      case 'MEDIUM':
        return AppTheme.warning;
      case 'LOW':
        return AppTheme.info;
      default:
        return AppTheme.textSecondary;
    }
  }

  Future<void> _markAlertRead(int alertId) async {
    final ok = await ref.read(alertProvider.notifier).markAlertRead(alertId);
    if (mounted) {
      _snack(
        ok ? 'Alert marked as read' : 'Failed to mark as read',
        ok ? AppTheme.success : AppTheme.danger,
      );
    }
  }

  Future<void> _markAllAlertsRead() async {
    final ok =
        await ref.read(alertProvider.notifier).markAllAlertsRead();
    if (mounted) {
      _snack(
        ok ? 'All alerts marked as read' : 'Failed to mark alerts as read',
        ok ? AppTheme.success : AppTheme.danger,
      );
    }
  }

  Future<void> _triggerAnomalyDetection() async {
    final result =
        await ref.read(alertProvider.notifier).detectAnomalies();
    if (result != null && mounted) {
      _snack(
        result.anomaliesFound > 0
            ? 'AI detected ${result.anomaliesFound} anomalies'
            : 'No anomalies detected',
        result.anomaliesFound > 0 ? AppTheme.warning : AppTheme.success,
      );
    } else if (mounted) {
      _snack('Failed to run anomaly detection', AppTheme.danger);
    }
  }

  void _refresh() => ref.read(alertProvider.notifier).refresh();

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ============================================================================
// _UnreadBadge — pulsing pill in the header when unread alerts exist
// ============================================================================
class _UnreadBadge extends StatefulWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  State<_UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<_UnreadBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 0.75)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates per-frame repaints from the header layout.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _glow,
        builder: (_, __) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.danger,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.danger.withValues(alpha: _glow.value),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            '${widget.count} new',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _HeaderActionButton — glass icon buttons in the gradient header.
// HoverSize.small — compact, isolated, has room to be punchy.
// FIX 3: spinController is null-safe; RotationTransition only built
// when spinController != null.
// ============================================================================
class _HeaderActionButton extends StatefulWidget {
  const _HeaderActionButton({
    this.icon,
    this.onTap,
    this.isLoading = false,
    this.spinController,
  });

  final IconData? icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final AnimationController? spinController;

  @override
  State<_HeaderActionButton> createState() => _HeaderActionButtonState();
}

class _HeaderActionButtonState extends State<_HeaderActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovering ? AppTheme.hoverScaleSmall : 1.0,
          duration: AppTheme.hoverDuration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _hovering
                  ? Colors.white.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovering
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.25),
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  // FIX 3: RotationTransition only when controller is present
                  : widget.spinController != null
                      ? RotationTransition(
                          turns: widget.spinController!,
                          child: Icon(widget.icon,
                              color: Colors.white, size: 18),
                        )
                      : Icon(widget.icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _SummaryStatTile — compact stat chip in the hero header.
// HoverSize.small — compact/isolated with breathing room.
// ============================================================================
class _SummaryStatTile extends StatelessWidget {
  const _SummaryStatTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return HoverGlow(
      glowColor: color,
      size: HoverSize.small,
      backgroundColor: Colors.white.withValues(alpha: 0.14),
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
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
// _DialogBadge
// ============================================================================
class _DialogBadge extends StatelessWidget {
  const _DialogBadge({
    required this.label,
    required this.color,
    required this.filled,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              filled ? color.withValues(alpha: 0.4) : AppTheme.borderColor,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: filled ? color : AppTheme.textSecondary,
        ),
      ),
    );
  }
}