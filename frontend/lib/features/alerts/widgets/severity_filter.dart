/// SeverityFilter — Phase 6 UI Enhancement
///
/// Rebuilt as a custom row of hoverable filter chips.
///
/// Hover classification:
///   - Each chip: compact, isolated, with breathing room on all 4 sides
///     (not stacked, not packed edge-to-edge against neighbors — just a row
///     of pills with consistent gap). Shape = compact/isolated → HoverSize.small.
///   - We don't use Flutter's FilterChip widget — it doesn't support the
///     glow/border/zoom treatment. Instead we build each chip via HoverGlow
///     directly, which gives us full control over border color, shadow, and
///     zoom in one place.
///
/// Active state: selected chip gets a solid colored background + stronger
/// border + the status-appropriate glow color. The count badge inside the
/// chip also intensifies. Non-selected chips stay muted until hover.
///
/// No FilterChip theme bleed-through: by owning the decoration ourselves we
/// avoid the "globally-themed widget rendering against two backgrounds" class
/// of bug (see Section 6, Lesson 5 of the UI summary).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';

class SeverityFilter extends StatelessWidget {
  const SeverityFilter({
    super.key,
    this.selectedSeverity,
    required this.onSeveritySelected,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
  });

  final String? selectedSeverity;
  final void Function(String?) onSeveritySelected;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;

  @override
  Widget build(BuildContext context) {
    final totalCount = criticalCount + highCount + mediumCount + lowCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none, // let the glow overflow without clipping
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            value: null,
            count: totalCount,
            chipColor: AppTheme.brandIndigo,
            selected: selectedSeverity == null,
            onTap: () => onSeveritySelected(null),
          ),
          const SizedBox(width: 9),
          _FilterChip(
            label: 'Critical',
            value: 'CRITICAL',
            count: criticalCount,
            chipColor: AppTheme.danger,
            selected: selectedSeverity == 'CRITICAL',
            onTap: () => onSeveritySelected(
                selectedSeverity == 'CRITICAL' ? null : 'CRITICAL'),
          ),
          const SizedBox(width: 9),
          _FilterChip(
            label: 'High',
            value: 'HIGH',
            count: highCount,
            chipColor: AppTheme.danger.withValues(alpha: 0.80),
            selected: selectedSeverity == 'HIGH',
            onTap: () =>
                onSeveritySelected(selectedSeverity == 'HIGH' ? null : 'HIGH'),
          ),
          const SizedBox(width: 9),
          _FilterChip(
            label: 'Medium',
            value: 'MEDIUM',
            count: mediumCount,
            chipColor: AppTheme.warning,
            selected: selectedSeverity == 'MEDIUM',
            onTap: () => onSeveritySelected(
                selectedSeverity == 'MEDIUM' ? null : 'MEDIUM'),
          ),
          const SizedBox(width: 9),
          _FilterChip(
            label: 'Low',
            value: 'LOW',
            count: lowCount,
            chipColor: AppTheme.info,
            selected: selectedSeverity == 'LOW',
            onTap: () =>
                onSeveritySelected(selectedSeverity == 'LOW' ? null : 'LOW'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _FilterChip — a single hoverable severity pill.
//
// Shape: compact, isolated pill with real breathing room on all sides.
// → HoverSize.small (punchy, appropriate for this shape).
//
// Does NOT use Flutter's FilterChip widget — we own the decoration entirely
// to avoid theme-bleed and to get full hover/glow control.
// ============================================================================
class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.count,
    required this.chipColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? value;
  final int count;
  final Color chipColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovering;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          // HoverSize.small = 1.10x, consistent with the named tier
          scale: _hovering ? AppTheme.hoverScaleSmall : 1.0,
          duration: AppTheme.hoverDuration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: widget.selected
                  ? widget.chipColor.withValues(alpha: 0.14)
                  : (_hovering
                      ? widget.chipColor.withValues(alpha: 0.08)
                      : AppTheme.bgElevated),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? widget.chipColor.withValues(alpha: widget.selected ? 0.7 : 0.4)
                    : AppTheme.borderColor,
                width: widget.selected ? 1.5 : 1.0,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: widget.chipColor.withValues(
                            alpha: widget.selected ? 0.30 : 0.16),
                        blurRadius: widget.selected ? 14 : 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label
                AnimatedDefaultTextStyle(
                  duration: AppTheme.hoverDuration,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: widget.selected
                        ? widget.chipColor
                        : (active
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary),
                  ),
                  child: Text(widget.label),
                ),
                // Count badge — only shown when count > 0
                if (widget.count > 0) ...[
                  const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: AppTheme.hoverDuration,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: widget.selected
                          ? widget.chipColor.withValues(alpha: 0.22)
                          : widget.chipColor.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.count.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: widget.selected
                            ? widget.chipColor
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}