/// Recommendation Card — Phase 7 UI Enhancement
///
/// NOTE: This file was NOT affected by the three reported bugs (no
/// `Expanded` is placed directly inside a `HoverEntrance`/`HoverCard` here,
/// and it has no generate-button logic). Included unchanged for
/// completeness alongside the fixed recommendations_screen.dart and
/// recommendation_summary.dart.
///
/// Hover classification:
///   Wide, content-rich card (type badge + title + reasoning paragraph
///   + savings block + action buttons), rendered in a dense list → HoverSize.subtle.
///   scaleEnabled: true — 1.045x is gentle enough for this width/height.
///
///   Type-badge: small isolated pill → HoverSize.small.
///   Apply / Dismiss buttons: HoverButton (expand: false).
///
/// Status glow: uses HoverGlowColors.forModuleAndStatus so each card glows
/// its own type color (e.g. CANCEL glows danger, DOWNGRADE glows warning).
/// Module default (brandPurple) is the fallback for unrecognised types.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../models/recommendation_models.dart';

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.onAction,
    this.onDismiss,
  });

  final RecommendationResponse recommendation;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;

  // Map each rec type to a meaningful status string that
  // HoverGlowColors.forModuleAndStatus can interpret, so each card glows
  // its own severity-equivalent color.
  String get _glowStatus {
    switch (recommendation.recType) {
      case 'CANCEL':
        return 'DANGER';
      case 'DOWNGRADE':
        return 'WARNING';
      case 'YEARLY_PLAN':
      case 'CONSOLIDATE':
      case 'ALTERNATIVE':
        return 'GOOD';
      default:
        return '';
    }
  }

  Color get _typeColor => recommendation.recTypeColor;

  @override
  Widget build(BuildContext context) {
    final isActioned = recommendation.isActioned;
    final glowColor = HoverGlowColors.forModuleAndStatus(
      moduleColor: AppTheme.recommendations,
      status: _glowStatus.isEmpty ? null : _glowStatus,
    );

    return HoverCard(
      glowColor: glowColor,
      size: HoverSize.subtle, // wide/dense list card → gentle tier
      padding: EdgeInsets.zero,
      onTap: null, // tapping the card body does nothing; buttons are explicit
      child: Opacity(
        opacity: isActioned ? 0.72 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Accent bar — type color, full width, top of card ─────────
            _TypeAccentBar(color: _typeColor, isActioned: isActioned),

            // ── Card body ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header row ─────────────────────────────────────────
                  _buildHeaderRow(isActioned),

                  const SizedBox(height: 10),

                  // ── Title ──────────────────────────────────────────────
                  Text(
                    recommendation.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // ── Reasoning ──────────────────────────────────────────
                  // Text-heavy block → scaleEnabled:false would be needed
                  // IF we were applying hover directly here. The parent
                  // HoverCard uses HoverSize.subtle instead, which keeps
                  // the zoom gentle (1.045x) rather than removing it entirely.
                  Text(
                    recommendation.reasoning,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 14),

                  // ── Bottom row ─────────────────────────────────────────
                  _buildBottomRow(isActioned),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Header row — type badge · source chip · spacer · status · savings block
  // ==========================================================================

  Widget _buildHeaderRow(bool isActioned) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Type badge — small isolated → HoverSize.small pattern (we let the
        // parent card own the hover; the badge itself is not separately hoverable)
        _TypeBadge(recommendation: recommendation),

        const SizedBox(width: 8),

        // Source chip
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.bgBase.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            recommendation.source,
            style: const TextStyle(
              fontSize: 9.5,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const Spacer(),

        // Applied badge (only when actioned)
        if (isActioned) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.4), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 12, color: AppTheme.success),
                SizedBox(width: 4),
                Text(
                  'Applied',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],

        // Savings block
        _SavingsBlock(recommendation: recommendation),
      ],
    );
  }

  // ==========================================================================
  // Bottom row — confidence · spacer · yearly savings · action buttons
  // ==========================================================================

  Widget _buildBottomRow(bool isActioned) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Confidence indicator
        if (recommendation.confidenceScore != null)
          _ConfidenceIndicator(
            score: recommendation.confidenceScore!,
          ),

        const Spacer(),

        // Yearly savings label (only pending cards)
        if (!isActioned && recommendation.potentialSaving != null) ...[
          Text(
            '${recommendation.yearlySaving}/yr potential',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
        ],

        // Action buttons — only for pending cards
        if (!isActioned) ...[
          HoverButton(
            label: 'Dismiss',
            outlined: true,
            expand: false,
            onPressed: onDismiss,
          ),
          const SizedBox(width: 8),
          HoverButton(
            label: 'Apply',
            expand: false,
            icon: Icons.check_rounded,
            onPressed: onAction,
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// _TypeAccentBar — thin colored stripe at the top of each card.
// Encodes the recommendation type visually without a label — same vocabulary
// as the severity bar in AlertCard (Phase 6).
// ============================================================================
class _TypeAccentBar extends StatelessWidget {
  const _TypeAccentBar({required this.color, required this.isActioned});
  final Color color;
  final bool isActioned;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: isActioned
            ? color.withValues(alpha: 0.35)
            : color,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusCards),
        ),
      ),
    );
  }
}

// ============================================================================
// _TypeBadge — pill with icon emoji + label.
// ============================================================================
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.recommendation});
  final RecommendationResponse recommendation;

  @override
  Widget build(BuildContext context) {
    final color = recommendation.recTypeColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(recommendation.recTypeIcon,
              style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            recommendation.recTypeLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _SavingsBlock — compact savings display in header row.
// ============================================================================
class _SavingsBlock extends StatelessWidget {
  const _SavingsBlock({required this.recommendation});
  final RecommendationResponse recommendation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.brandBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppTheme.brandBlue.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            recommendation.formattedSaving,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.brandBlue,
              height: 1.1,
            ),
          ),
          const Text(
            'per month',
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _ConfidenceIndicator — segmented bar visualising AI confidence score.
// ============================================================================
class _ConfidenceIndicator extends StatelessWidget {
  const _ConfidenceIndicator({required this.score});
  final double score;

  Color get _color {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return AppTheme.brandBlue;
    if (score >= 40) return AppTheme.warning;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    final filledSegments = (score / 20).round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.psychology_rounded,
            size: 13, color: _color),
        const SizedBox(width: 5),
        // 5-segment bar
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final filled = i < filledSegments;
            return Container(
              width: 6,
              height: 10,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: filled
                    ? _color
                    : AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const SizedBox(width: 5),
        Text(
          '${score.toInt()}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _color,
          ),
        ),
      ],
    );
  }
}