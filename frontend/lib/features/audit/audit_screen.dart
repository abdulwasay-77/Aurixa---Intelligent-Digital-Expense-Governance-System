/// Audit Trail Screen — Phase 11 UI Enhancement
///
/// Module accent: AppTheme.auditTrail (brandIndigo). Hero header gradient:
/// brandIndigo → brandPurple (matching the established hero vocabulary —
/// every other module pairs its accent with an adjacent Nebula hue;
/// auditTrail sits next to recommendations/behaviorLens on the brandPurple
/// side, so indigo→purple reads as "this module's corner" of the palette
/// rather than reusing wallet's blue→indigo or recommendations' purple→indigo
/// verbatim).
///
/// Hover classification (applied before writing any widget code):
///   • Hero header — wide, full-width banner → HoverEntrance wrap only, no
///     hover-zoom on the banner itself (same as every other module hero).
///   • Summary stat cells (Total/Creates/Updates/Deletes) — compact but
///     stacked tightly in a 4-across row with no real isolation between
///     them → HoverSize.subtle, NOT HoverSize.large. This is the exact
///     shape that tripped up Recommendations' stat tiles in Phase 7
///     (Lesson 2: "looks compact ≠ is compact") — applying that lesson
///     proactively here instead of shipping the bug and fixing it later.
///   • AuditEntryCard — handled inside audit_entry_card.dart
///     (HoverSize.subtle, list-heavy + expandable).
///   • Operation filter chips / table dropdown — handled inside
///     audit_filter_bar.dart (custom HoverSize.small-equivalent chips).
///   • Load More button — compact, isolated → HoverButton.
///
/// Status-glow showcase (per UI Enhancement Phase Summary §5, Phase 11
/// notes: "Best showcase for status-based glow"): INSERT=success,
/// UPDATE=warning, DELETE=danger, applied via HoverGlowColors
/// .forModuleAndStatus inside AuditEntryCard — module default (auditTrail)
/// is the fallback for any unrecognised operation string.
///
/// Layout safety:
///   • Hero Container has width: double.infinity (Lesson 8) — the summary
///     stat Row's Expanded children need this concrete constraint or they
///     measure against infinite width and crash.
///   • Stat row is null-guarded: cells render 0 instead of crashing when
///     summary is null, but the row itself never renders ahead of
///     AsyncData (the whole body is inside asyncState.when's data branch).
///   • No Expanded is ever the direct child of HoverEntrance (Lesson 10) —
///     every wrap here uses HoverEntrance around a fixed/intrinsic-size
///     child, never the reverse.
///   • No continuously-repeating AnimationController lives on an ancestor
///     of a ListView item (Lesson 7) — this screen owns no
///     AnimationController; the refresh icon uses a one-shot
///     AnimatedRotation driven by local state, not a repeating controller.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../providers/audit_provider.dart';
import 'widgets/audit_entry_card.dart';
import 'widgets/audit_filter_bar.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  // One-shot rotation flag for the refresh icon — NOT a repeating
  // AnimationController (Lesson 7 only forbids continuously-ticking
  // controllers near ListView items; this screen has none at all).
  bool _refreshSpinning = false;

  Future<void> _handleRefresh() async {
    setState(() => _refreshSpinning = true);
    await ref.read(auditProvider.notifier).refresh();
    if (mounted) setState(() => _refreshSpinning = false);
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(auditProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: auditAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.auditTrail),
        ),
        error: (err, _) => _ErrorState(
          message: err.toString(),
          onRetry: () => ref.read(auditProvider.notifier).refresh(),
        ),
        data: (auditState) {
          if (auditState.hasError) {
            return _ErrorState(
              message: auditState.errorMessage ?? 'Something went wrong',
              onRetry: () => ref.read(auditProvider.notifier).refresh(),
            );
          }
          return _AuditBody(
            auditState: auditState,
            refreshSpinning: _refreshSpinning,
            onRefresh: _handleRefresh,
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Body
// ════════════════════════════════════════════════════════════════════════

class _AuditBody extends ConsumerWidget {
  final AuditState auditState;
  final bool refreshSpinning;
  final VoidCallback onRefresh;

  const _AuditBody({
    required this.auditState,
    required this.refreshSpinning,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(auditProvider.notifier);
    final hasFilters = auditState.selectedOperation != null ||
        auditState.selectedTable != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Hero header (title + refresh + summary stats) ─────────────
        _buildHeroHeader(auditState, refreshSpinning, onRefresh),

        // ── Filter bar ───────────────────────────────────────────────
        const SizedBox(height: 4),
        AuditFilterBar(
          auditState: auditState,
          onOperationSelected: (op) => notifier.filterByOperation(op),
          onTableSelected: (tbl) => notifier.filterByTable(tbl),
        ),

        // ── Active filter info row ──────────────────────────────────
        if (hasFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
              '${auditState.totalCount} result${auditState.totalCount == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),

        // ── Log list ─────────────────────────────────────────────────
        Expanded(
          child: auditState.logs.isEmpty
              ? _EmptyState(
                  hasFilters: hasFilters,
                  onClearFilters: () => notifier.filterByOperation(null),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: auditState.logs.length +
                      (auditState.hasMorePages ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == auditState.logs.length) {
                      return _LoadMoreButton(onTap: () => notifier.loadMore());
                    }
                    return HoverEntrance(
                      index: index,
                      child: AuditEntryCard(entry: auditState.logs[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // Hero Header
  //
  // width: double.infinity is REQUIRED (Lesson 8) — without it the stat
  // row's Expanded children measure against infinite width.
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildHeroHeader(
    AuditState auditState,
    bool refreshSpinning,
    VoidCallback onRefresh,
  ) {
    final summary = auditState.summary;
    final total = summary?.totalEntries ?? 0;
    final inserts = summary?.insertCount ?? 0;
    final updates = summary?.updateCount ?? 0;
    final deletes = summary?.deleteCount ?? 0;

    return HoverEntrance(
      index: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.auditTrail, AppTheme.brandPurple],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title row ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Audit Trail',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _RefreshGlassButton(
                  spinning: refreshSpinning,
                  onTap: onRefresh,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Summary stat row ──────────────────────────────────────
            // 4-across, tightly packed → HoverSize.subtle (Lesson 2).
            Row(
              children: [
                Expanded(
                  child: HoverEntrance(
                    index: 1,
                    child: _HeroStatTile(
                      label: 'Total',
                      value: total,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HoverEntrance(
                    index: 2,
                    child: _HeroStatTile(
                      label: 'Creates',
                      value: inserts,
                      color: AppTheme.success,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HoverEntrance(
                    index: 3,
                    child: _HeroStatTile(
                      label: 'Updates',
                      value: updates,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HoverEntrance(
                    index: 4,
                    child: _HeroStatTile(
                      label: 'Deletes',
                      value: deletes,
                      color: AppTheme.danger,
                    ),
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

// ════════════════════════════════════════════════════════════════════════
// _HeroStatTile — compact but packed 4-across → HoverSize.subtle.
// Glass tile on the gradient hero, same vocabulary as other modules'
// in-header stat tiles.
// ════════════════════════════════════════════════════════════════════════

class _HeroStatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _HeroStatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return HoverGlow(
      glowColor: color == Colors.white ? Colors.white : color,
      size: HoverSize.subtle,
      borderRadius: 14,
      backgroundColor: Colors.white.withValues(alpha: 0.12),
      border: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// _RefreshGlassButton — header action button. Small, isolated → punchy
// tier. One-shot AnimatedRotation tied to a local bool, not a repeating
// AnimationController (Lesson 7 doesn't apply — there's no continuous
// ticking here, just a single 0→1 turn driven by refreshSpinning).
// ════════════════════════════════════════════════════════════════════════

class _RefreshGlassButton extends StatefulWidget {
  const _RefreshGlassButton({required this.spinning, required this.onTap});

  final bool spinning;
  final VoidCallback onTap;

  @override
  State<_RefreshGlassButton> createState() => _RefreshGlassButtonState();
}

class _RefreshGlassButtonState extends State<_RefreshGlassButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Refresh',
      child: MouseRegion(
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    Colors.white.withValues(alpha: _hovering ? 0.28 : 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AnimatedRotation(
                turns: widget.spinning ? 1 : 0,
                duration: const Duration(milliseconds: 640),
                curve: Curves.easeInOut,
                child: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Empty State
// ════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;

  const _EmptyState({required this.hasFilters, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 56,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No entries match this filter' : 'No audit activity yet',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Try a different filter or clear to see all entries.'
                  : 'Subscription changes and wallet activity are tracked here.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              HoverTextLink(text: 'Clear filters', onTap: onClearFilters),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Load-More Button — compact, isolated → HoverButton.
// ════════════════════════════════════════════════════════════════════════

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: HoverButton(
        label: 'Load More',
        icon: Icons.expand_more_rounded,
        outlined: true,
        expand: false,
        onPressed: onTap,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Error State
// ════════════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.danger.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
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