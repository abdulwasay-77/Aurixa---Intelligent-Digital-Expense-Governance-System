/// SubVault Screen — Full Subscription Management
/// Content only — Sidebar (and the app's only Scaffold) lives in AppShell.
///
/// Phase 3 rebuild:
///   - Removed the screen's own Scaffold/AppBar — it was duplicating
///     chrome that AppShell already provides; every other rebuilt screen
///     (Dashboard) is content-only, so this brings SubVault in line.
///   - Header is now an inline gradient hero band (SubVault's module
///     color = brandBlue) matching the dashboard's hero-header
///     vocabulary, with the search bar and category filter built in.
///   - Stats row rebuilt on the dashboard's HoverCard stat-tile pattern
///     instead of a plain Container — Total / Active / Monthly Spend now
///     get their own module-accent glow.
///   - Subscription list entrance-staggers via HoverEntrance, cards use
///     the default scale-enabled HoverCard with generous 16px vertical
///     gaps so the zoom never overlaps a neighbor (confirmed approach
///     after the Phase 2 sidebar lesson).
///   - BUG FIX: editing a subscription previously always built and sent
///     a CreateSubscriptionRequest, even though
///     SubscriptionNotifier.updateSubscription expects an
///     UpdateSubscriptionRequest — would have failed at the type
///     boundary. The dialog now builds the correct request type per
///     mode (see add_edit_subscription_dialog.dart), and this screen's
///     _updateSubscription is now properly typed instead of `dynamic`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../providers/subscription_provider.dart';
import '../../models/subscription_models.dart';
import 'widgets/subscription_card.dart';
import 'widgets/add_edit_subscription_dialog.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  String _searchQuery = '';
  String _filterCategory = 'All';
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(subscriptionProvider);

    return asyncState.when(
      loading: () => const _SubVaultLoading(),
      error: (error, _) => _SubVaultError(
        message: error.toString(),
        onRetry: _refresh,
      ),
      data: (state) {
        if (state.hasError) {
          return _SubVaultError(
            message: state.errorMessage ?? 'Failed to load subscriptions',
            onRetry: _refresh,
          );
        }

        final filtered = _filterSubscriptions(
          state.subscriptions,
          _searchQuery,
          _filterCategory,
        );

        return RefreshIndicator(
          color: AppTheme.brandBlue,
          backgroundColor: AppTheme.bgSurface,
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HoverEntrance(
                        index: 0,
                        child: _SubVaultHeader(
                          searchQuery: _searchQuery,
                          filterCategory: _filterCategory,
                          categoryOptions: _getCategoryOptions(state),
                          onSearchChanged: (v) =>
                              setState(() => _searchQuery = v.toLowerCase()),
                          onCategoryChanged: (v) =>
                              setState(() => _filterCategory = v),
                          onAdd: _showAddDialog,
                          searchFocusNode: _searchFocusNode,
                        ),
                      ),
                      const SizedBox(height: 20),
                      HoverEntrance(
                        index: 1,
                        child: _StatsRow(state: state),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(hasSearch: _searchQuery.isNotEmpty),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final sub = filtered[index];
                      return HoverEntrance(
                        index: index,
                        child: SubscriptionCard(
                          subscription: sub,
                          onEdit: () => _showEditDialog(sub),
                          onCancel: () => _showCancelDialog(sub),
                          onUsageUpdate: () => _showUsageUpdateDialog(sub),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // Filtering helpers
  // ==========================================================================

  List<SubscriptionResponse> _filterSubscriptions(
    List<SubscriptionResponse> subs,
    String query,
    String category,
  ) {
    return subs.where((sub) {
      final matchesSearch = query.isEmpty ||
          sub.serviceName.toLowerCase().contains(query) ||
          sub.categoryName.toLowerCase().contains(query) ||
          (sub.vendorName?.toLowerCase().contains(query) ?? false);

      final matchesCategory = category == 'All' || sub.categoryName == category;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<String> _getCategoryOptions(SubscriptionState state) {
    return state.categorySummary.map((c) => c.categoryName).toList();
  }

  // ==========================================================================
  // Dialogs
  // ==========================================================================

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AddEditSubscriptionDialog(
        onSave: _createSubscription,
      ),
    );
  }

  void _showEditDialog(SubscriptionResponse sub) {
    showDialog(
      context: context,
      builder: (context) => AddEditSubscriptionDialog(
        subscription: sub,
        onUpdate: (request) => _updateSubscription(sub.subId, request),
      ),
    );
  }

  void _showCancelDialog(SubscriptionResponse sub) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: Text('Are you sure you want to cancel "${sub.serviceName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelSubscription(sub.subId);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  void _showUsageUpdateDialog(SubscriptionResponse sub) {
    int newScore = sub.usageScore;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Usage Score'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sub.serviceName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  children: [
                    Text(
                      'Score: $newScore / 10',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Slider(
                      value: newScore.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: _getScoreColor(newScore),
                      inactiveColor: AppTheme.borderColor,
                      onChanged: (value) {
                        setDialogState(() => newScore = value.toInt());
                      },
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Low', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        Text('High', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateUsageScore(sub.subId, newScore);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 8) return AppTheme.success;
    if (score >= 5) return AppTheme.primary;
    if (score >= 3) return AppTheme.warning;
    return AppTheme.danger;
  }

  // ==========================================================================
  // CRUD Operations
  // ==========================================================================

  Future<void> _createSubscription(CreateSubscriptionRequest request) async {
    final notifier = ref.read(subscriptionProvider.notifier);
    final success = await notifier.createSubscription(request);
    if (success && mounted) {
      _showSnackBar('Subscription added successfully', AppTheme.success);
    } else if (mounted) {
      _showSnackBar('Failed to add subscription', AppTheme.danger);
    }
  }

  // BUG FIX: was `dynamic request` — now correctly typed to
  // UpdateSubscriptionRequest, matching what
  // SubscriptionNotifier.updateSubscription actually expects, and what
  // the dialog's onUpdate callback now actually builds.
  Future<void> _updateSubscription(
    int subId,
    UpdateSubscriptionRequest request,
  ) async {
    final notifier = ref.read(subscriptionProvider.notifier);
    final success = await notifier.updateSubscription(subId, request);
    if (success && mounted) {
      _showSnackBar('Subscription updated successfully', AppTheme.success);
    } else if (mounted) {
      _showSnackBar('Failed to update subscription', AppTheme.danger);
    }
  }

  Future<void> _cancelSubscription(int subId) async {
    final notifier = ref.read(subscriptionProvider.notifier);
    final success = await notifier.cancelSubscription(subId);
    if (success && mounted) {
      _showSnackBar('Subscription cancelled successfully', AppTheme.success);
    } else if (mounted) {
      _showSnackBar('Failed to cancel subscription', AppTheme.danger);
    }
  }

  Future<void> _updateUsageScore(int subId, int score) async {
    final notifier = ref.read(subscriptionProvider.notifier);
    final success = await notifier.updateUsageScore(subId, score);
    if (success && mounted) {
      _showSnackBar('Usage score updated', AppTheme.success);
    } else if (mounted) {
      _showSnackBar('Failed to update usage score', AppTheme.danger);
    }
  }

  void _refresh() {
    ref.read(subscriptionProvider.notifier).refresh();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ============================================================================
// Header — gradient hero band with title, search, filter, add button.
// ============================================================================
class _SubVaultHeader extends StatelessWidget {
  const _SubVaultHeader({
    required this.searchQuery,
    required this.filterCategory,
    required this.categoryOptions,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onAdd,
    required this.searchFocusNode,
  });

  final String searchQuery;
  final String filterCategory;
  final List<String> categoryOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onAdd;
  final FocusNode searchFocusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandBlue, AppTheme.brandIndigo],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCards),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandBlue.withValues(alpha: 0.3),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SubVault',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'All your subscriptions, in one place',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusButtons),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusButtons),
                  onTap: onAdd,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: AppTheme.brandBlue),
                        SizedBox(width: 6),
                        Text(
                          'Add Subscription',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.brandBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GlowFocusField(
                  focusNode: searchFocusNode,
                  borderRadius: AppTheme.radiusInputs,
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      focusNode: searchFocusNode,
                      cursorColor: AppTheme.brandBlue,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        // BUG FIX: previously this field sat inside a
                        // semi-transparent white Container with white
                        // text — but the global InputDecorationTheme
                        // (filled: true, fillColor: bgElevated) still
                        // merges in for any field not explicitly set to
                        // filled: false, washing out the contrast and
                        // making the typed text unreadable. GlowFocusField
                        // now owns a fully opaque AppTheme.bgElevated
                        // background directly, and this field explicitly
                        // disables the theme's fill so nothing competes
                        // with it.
                        filled: false,
                        hintText: 'Search subscriptions...',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppTheme.radiusInputs),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: filterCategory,
                    dropdownColor: AppTheme.bgSurface,
                    icon: const Icon(Icons.filter_list_rounded, color: Colors.white70, size: 20),
                    // Without selectedItemBuilder, DropdownButton reuses
                    // the SAME DropdownMenuItem widget for both the
                    // closed button (sits on the dark gradient header —
                    // needs white text) and the open menu (renders on
                    // dropdownColor, a light surface — needs dark text).
                    // That conflict was the actual bug: whichever color
                    // worked for one context was invisible in the other.
                    // selectedItemBuilder fixes it by giving the closed
                    // button its own independent rendering.
                    selectedItemBuilder: (context) {
                      final allLabels = ['All', ...categoryOptions];
                      return allLabels.map((cat) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cat == 'All' ? 'All Categories' : cat,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList();
                    },
                    items: [
                      const DropdownMenuItem(
                        value: 'All',
                        child: Text(
                          'All Categories',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        ),
                      ),
                      ...categoryOptions.map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(
                            cat,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onCategoryChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Stats Row — Total / Active / Monthly Spend, dashboard stat-tile pattern.
// ============================================================================
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = [
          _StatTile(
            icon: Icons.subscriptions_rounded,
            label: 'Total Subscriptions',
            value: '${state.totalCount}',
            accent: AppTheme.subVault,
          ),
          _StatTile(
            icon: Icons.check_circle_rounded,
            label: 'Active',
            value: '${state.activeCount}',
            accent: AppTheme.success,
          ),
          _StatTile(
            icon: Icons.payments_rounded,
            label: 'Monthly Spend',
            value: '\$${state.totalMonthlySpend.toStringAsFixed(0)}',
            accent: AppTheme.brandPurple,
          ),
        ];

        final isNarrow = constraints.maxWidth < 600;
        if (isNarrow) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: tiles
                .map((t) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: t))
                .toList(),
          );
        }

        return Row(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      glowColor: accent,
      size: HoverSize.small,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Empty state
// ============================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.subVault.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.subscriptions_rounded,
                size: 36,
                color: AppTheme.subVault,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch ? 'No subscriptions match your search' : 'No subscriptions yet',
              style: const TextStyle(fontSize: 17, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch ? 'Try a different search term' : 'Tap "Add Subscription" to get started',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Loading / error states — consistent with dashboard's branded treatment.
// ============================================================================
class _SubVaultLoading extends StatelessWidget {
  const _SubVaultLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(
          strokeWidth: 3.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandBlue),
        ),
      ),
    );
  }
}

class _SubVaultError extends StatelessWidget {
  const _SubVaultError({required this.message, required this.onRetry});

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