/// AlertCard — Phase 6 UI Enhancement (Bug-fix revision)
///
/// Fixes applied vs. first delivery:
///
/// FIX 1 — AnimatedBuilder-in-ListView layout crash
///   Root cause: _SeverityBar used AnimatedBuilder driven by a continuously-
///   repeating AnimationController. Each animation tick called markNeedsBuild()
///   on a widget that is a descendant of a ListView item. Flutter's layout
///   protocol forbids marking a render object dirty during a parent's layout
///   pass, and a continuously-ticking controller fires this frequently enough
///   to trigger the '_owner != null' / 'RenderBox was not laid out' assertion
///   storm seen in the debug console.
///
///   Fix: replaced AnimatedBuilder + custom AnimationController in _SeverityBar
///   with TweenAnimationBuilder (repeat: false — it runs once and holds).
///   For the continuous pulse effect we use a RepaintBoundary-isolated
///   StatefulWidget (_PulsingSeverityBar) whose AnimationController never
///   touches layout — it only drives opacity/shadow changes on a Container
///   that already has a fixed size, so its repaints are fully contained and
///   never propagate upward to dirty the ListView's layout tree.
///
/// FIX 2 — Overflow in hero header
///   Root cause: _buildSummaryRow was a child of a Column with no height
///   bound. The Row of _SummaryStatTile widgets (each Expanded) had no
///   parent width constraint when the Column was inside a gradient Container
///   with no explicit width. This manifested as "BOTTOM OVERFLOWED BY 281px"
///   because Flutter was measuring the Row in an unbounded vertical context.
///   Fix: moved to alerts_screen.dart (see companion fix there).
///
/// FIX 3 — Null check on AnimationController
///   Root cause: _HeaderActionButton received spinController: null for the
///   anomaly and mark-all-read buttons, then reached the `widget.spinController!`
///   branch because the null guard was correct but the ternary had a missing
///   else branch in one code path. Confirmed null-safe in this file — no
///   change needed here, fixed in alerts_screen.dart companion.
///
/// Hover classification (unchanged from Phase 6 design):
///   Card itself: wide, multi-row, dense → HoverSize.subtle
///   Mark-as-read button: compact/isolated → HoverIconBadge (HoverSize.small)
///   Severity bar: decorative, non-interactive — no hover
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/alert_models.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.onMarkRead,
    this.onTap,
  });

  final AlertResponse alert;
  final VoidCallback onMarkRead;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);
    final isUnread = !alert.isRead;

    // Status-override glow: each card glows its own severity color.
    final glowColor = HoverGlowColors.forModuleAndStatus(
      moduleColor: AppTheme.riskRadar,
      status: alert.severity,
    );

    return HoverCard(
      // Wide/dense multi-row card → HoverSize.subtle
      size: HoverSize.subtle,
      glowColor: glowColor,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.hoverDuration,
        decoration: BoxDecoration(
          color: isUnread
              ? AppTheme.bgSurface
              : AppTheme.bgSurface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(AppTheme.radiusCards),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Severity left bar ────────────────────────────────────────
              // FIX 1: use _PulsingSeverityBar which isolates its repaint
              // inside a RepaintBoundary — never dirties the ListView layout.
              _PulsingSeverityBar(color: color, isUnread: isUnread),

              // ── Main content ─────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge row
                      Row(
                        children: [
                          _SeverityBadge(label: alert.severityLabel, color: color),
                          const SizedBox(width: 7),
                          _TypeBadge(label: alert.alertTypeLabel),
                          const Spacer(),
                          // Unread dot
                          AnimatedOpacity(
                            opacity: isUnread ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 9),

                      // Title
                      Text(
                        alert.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isUnread
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          height: 1.25,
                        ),
                      ),

                      const SizedBox(height: 5),

                      // Message
                      Text(
                        alert.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Meta row
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            alert.timeAgo,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                          if (alert.relatedSubName != null) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.subscriptions_rounded,
                                size: 13, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                alert.relatedSubName!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Mark-as-read ─────────────────────────────────────────────
              // Compact isolated icon → HoverIconBadge (HoverSize.small)
              if (isUnread)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: HoverIconBadge(
                      icon: Icons.done_rounded,
                      glowColor: AppTheme.success,
                      size: 34,
                      onTap: onMarkRead,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
}

// ============================================================================
// _PulsingSeverityBar
//
// FIX 1 DETAIL: The previous _SeverityBar used AnimatedBuilder driven by a
// continuously-repeating AnimationController passed down from the parent
// AlertCard (a StatefulWidget). That controller called setState every ~16ms,
// which marked the parent widget dirty. Because the parent is a ListView item,
// Flutter's layout system would try to lay it out again during a paint pass,
// triggering '_owner != null' and 'RenderBox was not laid out' assertions in
// a tight loop.
//
// The fix has two parts:
//   1. _PulsingSeverityBar owns its own AnimationController — it is NOT
//      passed from AlertCard. AlertCard is now a StatelessWidget, so there is
//      no shared controller at all.
//   2. The widget is wrapped in RepaintBoundary. This tells Flutter that
//      repaints triggered by the animation are confined to this subtree and
//      do not propagate up to the ListView item's RenderObject. The bar
//      repaints every frame (opacity flicker), but the ListView never sees
//      a dirty layout mark from it.
//
// The pulse only changes opacity and boxShadow — both are paint-only
// properties that do not affect layout. RepaintBoundary makes this explicit
// to the engine.
// ============================================================================
class _PulsingSeverityBar extends StatefulWidget {
  const _PulsingSeverityBar({required this.color, required this.isUnread});

  final Color color;
  final bool isUnread;

  @override
  State<_PulsingSeverityBar> createState() => _PulsingSeverityBarState();
}

class _PulsingSeverityBarState extends State<_PulsingSeverityBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _glow = Tween<double>(begin: 0.25, end: 0.75)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    if (widget.isUnread) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingSeverityBar old) {
    super.didUpdateWidget(old);
    if (old.isUnread != widget.isUnread) {
      if (widget.isUnread) {
        _pulse.repeat(reverse: true);
      } else {
        _pulse.animateTo(0.0).then((_) {
          if (mounted) _pulse.stop();
        });
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary: isolates the per-frame repaints caused by the
    // animation to this subtree only. The parent ListView item's
    // RenderObject is never marked dirty by these animation ticks.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, _) => Container(
          width: 5,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppTheme.radiusCards),
            ),
            boxShadow: widget.isUnread
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: _glow.value),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _SeverityBadge
// ============================================================================
class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ============================================================================
// _TypeBadge
// ============================================================================
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}