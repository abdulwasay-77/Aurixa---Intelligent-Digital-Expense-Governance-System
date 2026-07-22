/// Recommendations Screen — Phase 7 UI Enhancement (FIXED)
///
/// Module accent: `AppTheme.recommendations` (brandPurple).
/// Hero header gradient: brandPurple → brandIndigo  (matching SubVault/
/// BehaviorLens/VelocityEngine/RiskRadar vocabulary).
///
/// === FIXES IN THIS VERSION ===
/// 1. `!semantics.parentDataDirty` assertion storm:
///    `_buildStatTile` previously did `HoverEntrance(child: Expanded(...))`.
///    `HoverEntrance` drives an `AnimatedBuilder` every frame; with `Expanded`
///    (a flex child) directly inside that animated subtree, Flutter
///    re-resolves flex parentData mid-layout during a semantics pass that
///    hasn't finished — causing the assertion storm. Fixed by flipping the
///    nesting: `Expanded(child: HoverEntrance(...))`.
/// 2. Zoom too aggressive: stat tiles sit in a dense 4-across row, not truly
///    isolated, so `HoverSize.large` (1.08x) is changed to `HoverSize.subtle`
///    (1.045x).
/// 3. Generate button: `isGenerating` used to be read from
///    `asyncState.value?.isGenerating`. The notifier's `generateRecommendations()`
///    ends by calling `refresh()`, which sets the provider to `AsyncLoading()`
///    — and `AsyncLoading.value` is `null`. So `isGenerating` collapsed back to
///    `false` immediately and the spinner / disabled state never held. Fixed
///    by tracking generation state locally in `_isGenerating`.
///
/// Hover classification (applied before writing every widget):
///   • Summary stat tiles — compact but stacked tightly in a 4-across row,
///     no real isolation → HoverSize.subtle (FIXED, was .large).
///   • Recommendation cards — wide, content-rich (type badge + title +
///     reasoning text + savings + action buttons), densely stacked in a
///     list → HoverSize.subtle.  scaleEnabled remains true; the card is NOT
///     so tall/variable that a gentle 1.045x zoom breaks layout.
///   • Type filter chips — small, isolated, horizontal scroll → custom
///     _RecoFilterChip (MouseRegion + AnimatedContainer) — same pattern as
///     Phase 6 SeverityFilter.  No Flutter FilterChip (theme-bleed risk).
///   • Header action buttons — compact glass tiles → HoverSize.small.
///   • Generate / Refresh icon buttons in header → HoverIconBadge.
///
/// Layout safety:
///   • Hero Container has `width: double.infinity` (Phase 6 Lesson 8).
///   • Summary stat row only rendered when `summary != null` (Phase 6 Lesson 8).
///   • No continuously-repeating AnimationController on any parent whose
///     child is a ListView item (Phase 6 Lesson 7).  The generate-spinner
///     lives inside a self-contained child StatefulWidget.
///   • `Expanded` is NEVER placed as the direct child of `HoverEntrance`
///     (Phase 7 Lesson 1 — see fix #1 above). Always wrap the other way:
///     `Expanded(child: HoverEntrance(child: ...))`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../providers/recommendation_provider.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/recommendation_summary.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState
    extends ConsumerState<RecommendationsScreen>
    with SingleTickerProviderStateMixin {
  // Single animation controller — drives only the refresh icon spin.
  // Owned here (top-level screen), never inside a ListView ancestor → safe.
  late final AnimationController _refreshSpin;

  String _selectedType = 'All';

  // FIX #3 — local source of truth for the Generate button's loading state.
  // `asyncState.value?.isGenerating` is unreliable because the provider
  // transitions through `AsyncLoading` (value == null) partway through the
  // generate flow (generateRecommendations() calls refresh() internally).
  bool _isGenerating = false;

  static const List<String> _typeOptions = [
    'All',
    'CANCEL',
    'DOWNGRADE',
    'YEARLY_PLAN',
    'CONSOLIDATE',
    'ALTERNATIVE',
  ];

  @override
  void initState() {
    super.initState();
    _refreshSpin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recommendationProvider.notifier).refresh();
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
    final asyncState = ref.watch(recommendationProvider);

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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.recommendations,
                  ),
                ),
              ),
              error: (error, _) => _buildErrorState(error.toString()),
              data: (state) {
                if (state.hasError) {
                  return _buildErrorState(
                    state.errorMessage ?? 'Failed to load recommendations',
                  );
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
  // width: double.infinity is REQUIRED — the inner Column passes this
  // concrete constraint down to the summary Row's Expanded children.
  // Without it, Flutter measures against infinite width → overflow crash
  // (same bug as Phase 6 RiskRadar, locked in Lesson 8).
  // ==========================================================================

  Widget _buildHeroHeader(AsyncValue<RecommendationState> asyncState) {
    // Only extract data when fully loaded — never render summary before it exists.
    final state = asyncState.value;
    final pendingCount = state?.summary?.pendingRecommendations ?? 0;

    // FIX #3 — use the locally-tracked flag instead of the provider's
    // transient AsyncValue, which goes null (AsyncLoading) mid-generation.
    final isGenerating = _isGenerating;

    return HoverEntrance(
      index: 0,
      child: Container(
        width: double.infinity, // CRITICAL — Phase 6 Lesson 8
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.recommendations, AppTheme.brandIndigo],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // never take infinite height
          children: [
            // ── Title row ────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Module icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Title + pending badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Recommendations',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 10),
                            _PendingBadge(count: pendingCount),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'AI-powered suggestions to optimise your spending',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Action buttons ───────────────────────────────────────
                _HeaderActionButton(
                  icon: Icons.auto_awesome,
                  label: 'Generate',
                  isLoading: isGenerating,
                  onTap: isGenerating ? null : _generateRecommendations,
                ),
                const SizedBox(width: 8),
                _HeaderActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'Refresh',
                  spinController: _refreshSpin,
                  onTap: _refresh,
                ),
              ],
            ),

            // ── Summary stat tiles — only when data is loaded ─────────
            // Null-guard: never render before provider has loaded.
            if (state?.summary != null) ...[
              const SizedBox(height: 20),
              _buildSummaryRow(state!),
            ],
          ],
        ),
      ),
    );
  }

  // Summary row: 4 compact stat tiles with breathing room.
  // Shape: dense 4-across row, not truly isolated → HoverSize.subtle (FIX #2).
  Widget _buildSummaryRow(RecommendationState state) {
    final monthly = state.savingsImpact?.monthlySavings ?? 0;
    final yearly = state.savingsImpact?.yearlySavings ?? 0;
    final pending = state.summary?.pendingRecommendations ?? 0;
    final actioned = state.summary?.actionedRecommendations ?? 0;

    return Row(
      children: [
        _buildStatTile(
          index: 1,
          icon: Icons.lightbulb_outline_rounded,
          label: 'Total',
          value: '${state.totalCount}',
          color: Colors.white,
        ),
        const SizedBox(width: 10),
        _buildStatTile(
          index: 2,
          icon: Icons.hourglass_top_rounded,
          label: 'Pending',
          value: '$pending',
          color: AppTheme.warning,
        ),
        const SizedBox(width: 10),
        _buildStatTile(
          index: 3,
          icon: Icons.check_circle_outline_rounded,
          label: 'Applied',
          value: '$actioned',
          color: AppTheme.success,
        ),
        const SizedBox(width: 10),
        _buildStatTile(
          index: 4,
          icon: Icons.savings_rounded,
          label: 'Save / mo',
          value: '\$${monthly.toStringAsFixed(0)}',
          color: Colors.white,
          subLabel: '\$${yearly.toStringAsFixed(0)}/yr',
        ),
      ],
    );
  }

  // Compact tile in a dense 4-across row → HoverSize.subtle (FIX #2).
  // Uses HoverGlow directly (not HoverCard) because these tiles need a
  // translucent white backgroundColor to sit against the gradient header.
  // HoverCard is a convenience wrapper that omits backgroundColor; HoverGlow
  // exposes it directly.
  //
  // FIX #1 — `Expanded` is now the OUTER widget and `HoverEntrance` is
  // nested inside it. Previously this was reversed
  // (`HoverEntrance(child: Expanded(...))`), which caused the
  // `!semantics.parentDataDirty` assertion storm: HoverEntrance's
  // AnimatedBuilder dirties layout every frame, and having a flex child
  // (Expanded) directly inside that animated subtree caused Flutter to
  // re-resolve flex parentData mid-layout during an unfinished semantics
  // pass.
  Widget _buildStatTile({
    required int index,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subLabel,
  }) {
    return Expanded(
      child: HoverEntrance(
        index: index,
        child: HoverGlow(
          glowColor: AppTheme.recommendations,
          size: HoverSize.subtle, // FIX #2 — was HoverSize.large
          backgroundColor: Colors.white.withValues(alpha: 0.14),
          borderRadius: AppTheme.radiusCards,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: color,
                          height: 1.1,
                        ),
                      ),
                      if (subLabel != null)
                        Text(
                          subLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white60,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // Data body
  // ==========================================================================

  Widget _buildDataBody(RecommendationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Type filter bar ───────────────────────────────────────────────
        HoverEntrance(
          index: 5,
          child: Container(
            color: AppTheme.bgBase,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _typeOptions.map((type) {
                  final isSelected = _selectedType == type;
                  final isAll = type == 'All';
                  final count = isAll
                      ? state.totalCount
                      : (state.summary?.byType[type] ?? 0);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _RecoFilterChip(
                      label: isAll ? 'All' : _typeLabel(type),
                      count: count,
                      color: isAll ? AppTheme.recommendations : _typeColor(type),
                      isSelected: isSelected,
                      onTap: () => _onFilterTap(type, isSelected),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // ── Top Saving spotlight (only when not filtered + exists) ────────
        if (_selectedType == 'All' && state.summary?.topSavingRecommendation != null)
          HoverEntrance(
            index: 6,
            child: _TopSavingSpotlight(
              rec: state.summary!.topSavingRecommendation!,
            ),
          ),

        // ── Recommendation list ───────────────────────────────────────────
        Expanded(
          child: state.recommendations.isEmpty
              ? _buildEmptyState(state)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: state.recommendations.length,
                  itemBuilder: (context, i) {
                    return HoverEntrance(
                      index: 7 + i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RecommendationCard(
                          recommendation: state.recommendations[i],
                          onAction: () =>
                              _actionRecommendation(state.recommendations[i].recId),
                          onDismiss: () =>
                              _dismissRecommendation(state.recommendations[i].recId),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // ── Pagination ────────────────────────────────────────────────────
        if (state.filteredCount > state.pageSize)
          _buildPagination(state),
      ],
    );
  }

  // ==========================================================================
  // Pagination
  // ==========================================================================

  Widget _buildPagination(RecommendationState state) {
    final totalPages = (state.filteredCount / state.pageSize).ceil();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HoverIconBadge(
            icon: Icons.chevron_left_rounded,
            glowColor: AppTheme.recommendations,
            onTap: state.page > 1
                ? () => ref
                    .read(recommendationProvider.notifier)
                    .goToPage(state.page - 1)
                : null,
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              'Page ${state.page} of $totalPages',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          HoverIconBadge(
            icon: Icons.chevron_right_rounded,
            glowColor: AppTheme.recommendations,
            onTap: state.page < totalPages
                ? () => ref
                    .read(recommendationProvider.notifier)
                    .goToPage(state.page + 1)
                : null,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Empty state
  // ==========================================================================

  Widget _buildEmptyState(RecommendationState state) {
    final isFiltered = _selectedType != 'All';
    final hasAny = state.totalCount > 0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.recommendations, AppTheme.brandIndigo],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              hasAny ? Icons.filter_list_off_rounded : Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered
                ? 'No ${_typeLabel(_selectedType)} Suggestions'
                : 'No Recommendations Yet',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Try a different category or view all suggestions.'
                : (state.isGenerating
                    ? 'Generating your personalised suggestions…'
                    : 'Tap Generate to get AI-powered savings suggestions.'),
            style: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (isFiltered)
            HoverButton(
              label: 'Show All',
              outlined: true,
              expand: false,
              onPressed: () {
                setState(() => _selectedType = 'All');
                _filterRecommendations(null);
              },
            )
          else if (!_isGenerating)
            HoverButton(
              label: 'Generate Recommendations',
              icon: Icons.auto_awesome_rounded,
              expand: false,
              onPressed: _generateRecommendations,
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Error state
  // ==========================================================================

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.error_outline_rounded,
                size: 32, color: AppTheme.danger),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          HoverButton(
            label: 'Retry',
            expand: false,
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Helpers
  // ==========================================================================

  String _typeLabel(String type) {
    switch (type) {
      case 'CANCEL':
        return 'Cancel';
      case 'DOWNGRADE':
        return 'Downgrade';
      case 'YEARLY_PLAN':
        return 'Yearly';
      case 'CONSOLIDATE':
        return 'Consolidate';
      case 'ALTERNATIVE':
        return 'Alternative';
      default:
        return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'CANCEL':
        return AppTheme.danger;
      case 'DOWNGRADE':
        return AppTheme.warning;
      case 'YEARLY_PLAN':
        return AppTheme.brandBlue;
      case 'CONSOLIDATE':
        return AppTheme.brandIndigo;
      case 'ALTERNATIVE':
        return AppTheme.info;
      default:
        return AppTheme.textSecondary;
    }
  }

  void _onFilterTap(String type, bool isSelected) {
    if (isSelected && type != 'All') {
      setState(() => _selectedType = 'All');
      _filterRecommendations(null);
    } else if (!isSelected) {
      setState(() => _selectedType = type);
      _filterRecommendations(type == 'All' ? null : type);
    }
  }

  // ==========================================================================
  // Actions
  // ==========================================================================

  Future<void> _filterRecommendations(String? type) async {
    await ref.read(recommendationProvider.notifier).filterByType(type);
  }

  Future<void> _actionRecommendation(int recId) async {
    final ok = await ref
        .read(recommendationProvider.notifier)
        .actionRecommendation(recId, 'APPLIED');
    if (mounted) {
      _showSnackBar(
        ok ? 'Recommendation applied!' : 'Failed to apply recommendation',
        ok ? AppTheme.success : AppTheme.danger,
      );
    }
  }

  Future<void> _dismissRecommendation(int recId) async {
    final ok = await ref
        .read(recommendationProvider.notifier)
        .actionRecommendation(recId, 'DISMISSED');
    if (mounted) {
      _showSnackBar(
        ok ? 'Recommendation dismissed' : 'Failed to dismiss',
        ok ? AppTheme.textSecondary : AppTheme.danger,
      );
    }
  }

  // FIX #3 — wrap the generate call with a locally-owned `_isGenerating`
  // flag so the button's enabled/disabled + spinner state stays correct
  // even while the provider transitions through AsyncLoading (value: null)
  // partway through (generateRecommendations() calls refresh() internally).
  Future<void> _generateRecommendations() async {
    setState(() => _isGenerating = true);
    final ok =
        await ref.read(recommendationProvider.notifier).generateRecommendations();
    if (mounted) {
      setState(() => _isGenerating = false);
      if (ok) setState(() => _selectedType = 'All');
      _showSnackBar(
        ok
            ? 'Recommendations generated!'
            : 'Failed to generate recommendations',
        ok ? AppTheme.success : AppTheme.danger,
      );
    }
  }

  void _refresh() {
    _refreshSpin.forward(from: 0);
    setState(() => _selectedType = 'All');
    ref.read(recommendationProvider.notifier).refresh();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(color: Colors.white, fontSize: 13.5)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ============================================================================
// _PendingBadge — self-contained pulsing badge for unactioned count.
//
// Owns its own AnimationController (Phase 6 Lesson 7): never share a
// continuously-repeating controller with a parent that is an ancestor of a
// ListView item.  This widget is in the header (not a list item), but the
// self-contained pattern is applied proactively for correctness.
// ============================================================================
class _PendingBadge extends StatefulWidget {
  const _PendingBadge({required this.count});
  final int count;

  @override
  State<_PendingBadge> createState() => _PendingBadgeState();
}

class _PendingBadgeState extends State<_PendingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white38, width: 1),
          ),
          child: Text(
            '${widget.count} pending',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _HeaderActionButton — compact glass tile in the hero header.
//
// Shape: compact/isolated → HoverSize.small.
// ============================================================================
class _HeaderActionButton extends StatefulWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.spinController,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  /// Pass a non-null controller to make the icon spin on tap (refresh).
  final AnimationController? spinController;

  @override
  State<_HeaderActionButton> createState() => _HeaderActionButtonState();
}

class _HeaderActionButtonState extends State<_HeaderActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.isLoading;

    Widget iconWidget = widget.spinController != null
        ? RotationTransition(
            turns: widget.spinController!,
            child: Icon(widget.icon,
                color: Colors.white,
                size: 18),
          )
        : (widget.isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(widget.icon, color: Colors.white, size: 18));

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedScale(
          scale: _hovering ? AppTheme.hoverScaleSmall : 1.0,
          duration: AppTheme.hoverDuration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _hovering
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovering
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: AppTheme.recommendations.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _RecoFilterChip — custom filter chip.
//
// Shape: small, isolated, horizontal scroll row → HoverSize.small equivalent
// (MouseRegion + AnimatedScale + AnimatedContainer).  No Flutter FilterChip
// — drops global theme fills in exactly the same way SeverityFilter did in
// Phase 6 (Phase 6 Lesson 9).
// ============================================================================
class _RecoFilterChip extends StatefulWidget {
  const _RecoFilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_RecoFilterChip> createState() => _RecoFilterChipState();
}

class _RecoFilterChipState extends State<_RecoFilterChip> {
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active
                  ? widget.color.withValues(alpha: 0.14)
                  : AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? widget.color : AppTheme.borderColor,
                width: active ? 1.5 : 1,
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.30),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: widget.isSelected
                        ? widget.color
                        : AppTheme.textSecondary,
                  ),
                ),
                if (widget.count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? widget.color.withValues(alpha: 0.20)
                          : AppTheme.bgBase.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: widget.isSelected
                            ? widget.color
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

// ============================================================================
// _TopSavingSpotlight — hero callout for the highest-value recommendation.
//
// Shown only when filter is 'All' and the summary includes a top saver.
// Shape: wide banner (full width, not compact/isolated) → scaleEnabled: false.
// ============================================================================
class _TopSavingSpotlight extends StatelessWidget {
  const _TopSavingSpotlight({required this.rec});

  final dynamic rec; // RecommendationResponse

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: HoverGlow(
        glowColor: AppTheme.success,
        scaleEnabled: false, // wide banner — border+glow only, no zoom
        borderRadius: AppTheme.radiusCards,
        backgroundColor: AppTheme.bgSurface,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Trophy icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.success, AppTheme.brandIndigo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Top Saving Opportunity',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rec.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rec.formattedSaving,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.success,
                    ),
                  ),
                  const Text(
                    'per month',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}