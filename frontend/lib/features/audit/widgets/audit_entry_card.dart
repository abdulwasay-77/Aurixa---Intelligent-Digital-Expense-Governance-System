/// AuditEntryCard — Phase 11 UI Enhancement
///
/// Hover classification:
///   Wide, list-heavy row (icon + table label + operation badge + record
///   id + timestamp, packed into a dense scrolling list) → HoverSize.subtle
///   (1.045x), same shape-reasoning as AlertCard (Phase 6) and
///   RecommendationCard (Phase 7) — a list-heavy card never gets the
///   punchier HoverSize.small/large tiers.
///
/// Structural note — expand/collapse vs. hover, kept on separate
///   transforms (same principle as the entrance/hover separation rule):
///   This card is the first one in the app that combines a tap-to-expand
///   interaction with hover zoom. The two are kept on fully separate
///   widgets:
///     - HoverGlow owns ONLY the hover AnimatedScale + border/glow
///       AnimatedContainer (the outer wrapper).
///     - The expand/collapse height change is owned by a SEPARATE
///       AnimatedSize + child Column inside HoverGlow's child — it never
///       touches HoverGlow's own Transform/decoration.
///   This mirrors the documented HoverEntrance-vs-hover separation rule:
///   never let two independent animated states (entrance fade, hover zoom,
///   expand height) share one Transform/AnimatedContainer, or one will
///   silently override or destabilize the other. Tapping the row toggles
///   `_expanded`; HoverGlow's own onTap is intentionally left null on the
///   row content and the InkWell handles the tap instead — same division
///   of responsibility as AlertCard's onTap-vs-inner-button split, just
///   applied to expand instead of navigation.
///
/// Glow color: status-override via HoverGlowColors.forModuleAndStatus.
///   INSERT → success, UPDATE → warning, DELETE → danger. This is the
///   module's flagship showcase for the status-override rule per the UI
///   Enhancement Phase Summary §5 (Phase 11 notes).
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/audit_models.dart';

class AuditEntryCard extends StatefulWidget {
  final AuditLogResponse entry;

  const AuditEntryCard({super.key, required this.entry});

  @override
  State<AuditEntryCard> createState() => _AuditEntryCardState();
}

class _AuditEntryCardState extends State<AuditEntryCard> {
  bool _expanded = false;

  // ── Helpers ───────────────────────────────────────────────────────────

  Color _operationColor(String op) {
    switch (op.toUpperCase()) {
      case 'INSERT':
        return AppTheme.success;
      case 'UPDATE':
        return AppTheme.warning;
      case 'DELETE':
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
    }
  }

  IconData _operationIcon(String op) {
    switch (op.toUpperCase()) {
      case 'INSERT':
        return Icons.add_circle_outline;
      case 'UPDATE':
        return Icons.edit_outlined;
      case 'DELETE':
        return Icons.delete_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _tableLabel(String tableName) {
    return tableName
        .split('_')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'Unknown time';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formattedDate(DateTime? dt) {
    if (dt == null) return '—';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $h:$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final opColor = _operationColor(entry.operation);
    final hasDetails =
        (entry.oldValues != null && entry.oldValues!.isNotEmpty) ||
            (entry.newValues != null && entry.newValues!.isNotEmpty) ||
            entry.recordId != null;

    final glowColor = HoverGlowColors.forModuleAndStatus(
      moduleColor: AppTheme.auditTrail,
      status: entry.operation,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: HoverGlow(
        glowColor: glowColor,
        size: HoverSize.subtle,
        borderRadius: AppTheme.radiusInputs,
        backgroundColor: AppTheme.bgElevated,
        // onTap stays null here — the InkWell below owns the expand
        // toggle so the ripple feedback lands exactly on the tappable
        // main row, not the whole card including the detail section.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Main row ──────────────────────────────────────────────
            InkWell(
              onTap: hasDetails
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusInputs),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Operation icon badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: opColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _operationIcon(entry.operation),
                        color: opColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Table + operation label
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _tableLabel(entry.tableName),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: opColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.operation,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: opColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            entry.recordId != null
                                ? 'Record #${entry.recordId}  ·  ${_timeAgo(entry.performedAt)}'
                                : _timeAgo(entry.performedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (hasDetails)
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: AppTheme.hoverDuration,
                        curve: Curves.easeOut,
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: AppTheme.textMuted,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Expanded detail section ──────────────────────────────
            // Owned by AnimatedSize, fully separate from HoverGlow's own
            // AnimatedScale/AnimatedContainer — expand state never shares
            // a Transform with the hover zoom (see file header note).
            AnimatedSize(
              duration: AppTheme.hoverDuration,
              curve: Curves.easeOut,
              child: (_expanded && hasDetails)
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(
                          height: 1,
                          color: AppTheme.borderColor.withValues(alpha: 0.6),
                          indent: 14,
                          endIndent: 14,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (entry.performedAt != null)
                                _detailRow(
                                  Icons.access_time_outlined,
                                  'Timestamp',
                                  _formattedDate(entry.performedAt),
                                ),
                              if (entry.recordId != null)
                                _detailRow(Icons.tag, 'Record ID',
                                    '#${entry.recordId}'),
                              if (entry.ipAddress != null)
                                _detailRow(Icons.router_outlined,
                                    'IP Address', entry.ipAddress!),
                              if (entry.oldValues != null &&
                                  entry.oldValues!.isNotEmpty)
                                _multilineRow(
                                  Icons.history,
                                  'Before',
                                  entry.oldValues!,
                                  AppTheme.danger,
                                ),
                              if (entry.newValues != null &&
                                  entry.newValues!.isNotEmpty)
                                _multilineRow(
                                  Icons.check_circle_outline,
                                  'After',
                                  entry.newValues!,
                                  AppTheme.success,
                                ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _multilineRow(
      IconData icon, String label, String value, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}