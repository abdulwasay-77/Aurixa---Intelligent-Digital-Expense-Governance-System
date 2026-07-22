/// AuditFilterBar — Phase 11 UI Enhancement
///
/// Hover classification:
///   Operation chips — small, isolated, horizontal scroll, real gaps
///   between pills → same pattern as Phase 6 SeverityFilter / Phase 7
///   _RecoFilterChip / Phase 10 _TxnFilterChip: custom HoverGlow-style
///   chip (MouseRegion + AnimatedScale + AnimatedContainer), HoverSize.small
///   equivalent (1.10x). No Flutter FilterChip — theme-bleed risk
///   (Lesson 9).
///
///   Table filter dropdown — plain DropdownButton rendered on bgSurface
///   (light), with every text-bearing style set explicitly (Lesson 4).
///   This is NOT a two-background-context case (Lesson 5 doesn't apply
///   here) — the dropdown's trigger sits on the same light surface as its
///   popup, unlike a dropdown whose trigger lives on a dark gradient
///   header. selectedItemBuilder is therefore unnecessary.
///
/// Color vocabulary matches the audit module's status-glow rule used
/// throughout this phase: INSERT=success, UPDATE=warning, DELETE=danger,
/// All=auditTrail (brandIndigo, the module default).
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/audit_provider.dart';

class AuditFilterBar extends StatelessWidget {
  final AuditState auditState;
  final void Function(String?) onOperationSelected;
  final void Function(String?) onTableSelected;

  const AuditFilterBar({
    super.key,
    required this.auditState,
    required this.onOperationSelected,
    required this.onTableSelected,
  });

  static const _operations = ['All', 'INSERT', 'UPDATE', 'DELETE'];

  Color _chipColor(String op) {
    switch (op) {
      case 'INSERT':
        return AppTheme.success;
      case 'UPDATE':
        return AppTheme.warning;
      case 'DELETE':
        return AppTheme.danger;
      default:
        return AppTheme.auditTrail;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOp = auditState.selectedOperation;
    final tables = auditState.summary?.affectedTables ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Operation filter chips ────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none, // let the glow overflow without clipping
            child: Row(
              children: _operations.map((op) {
                final isAll = op == 'All';
                final isSelected =
                    isAll ? selectedOp == null : selectedOp == op;
                final color = _chipColor(op);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _AuditFilterChip(
                    label: op,
                    color: color,
                    isSelected: isSelected,
                    onTap: () => onOperationSelected(isAll ? null : op),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Table filter dropdown (only when multiple tables exist) ───
          if (tables.length > 1) ...[
            const SizedBox(height: 10),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusInputs),
                border: Border.all(
                  color: auditState.selectedTable != null
                      ? AppTheme.auditTrail
                      : AppTheme.borderColor,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: auditState.selectedTable,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down,
                      size: 16, color: AppTheme.textSecondary),
                  dropdownColor: AppTheme.bgElevated,
                  style: TextStyle(
                    fontSize: 12,
                    color: auditState.selectedTable != null
                        ? AppTheme.auditTrail
                        : AppTheme.textSecondary,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'All Tables',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                    ...tables.map(
                      (t) => DropdownMenuItem<String?>(
                        value: t,
                        child: Text(
                          t,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textPrimary),
                        ),
                      ),
                    ),
                  ],
                  onChanged: onTableSelected,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// _AuditFilterChip — same vocabulary as SeverityFilter/_RecoFilterChip/
// _TxnFilterChip: compact, isolated pill → HoverSize.small equivalent.
// ============================================================================
class _AuditFilterChip extends StatefulWidget {
  const _AuditFilterChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_AuditFilterChip> createState() => _AuditFilterChipState();
}

class _AuditFilterChipState extends State<_AuditFilterChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _hovering;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.color.withValues(alpha: 0.16)
                  : (_hovering
                      ? widget.color.withValues(alpha: 0.08)
                      : AppTheme.bgElevated),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? widget.color
                        .withValues(alpha: widget.isSelected ? 0.7 : 0.4)
                    : AppTheme.borderColor,
                width: widget.isSelected ? 1.5 : 1.0,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(
                            alpha: widget.isSelected ? 0.30 : 0.16),
                        blurRadius: widget.isSelected ? 14 : 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight:
                    widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                color: widget.isSelected
                    ? widget.color
                    : (active ? AppTheme.textPrimary : AppTheme.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}