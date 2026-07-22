/// TransactionList — Phase 10 UI Enhancement
///
/// Hover classification:
///   Header row (title + summary chips) — static display, no hover.
///   Filter bar — small, isolated, horizontal scroll → custom
///     _TxnFilterChip (MouseRegion + AnimatedScale + AnimatedContainer),
///     same vocabulary as Phase 6 SeverityFilter / Phase 7 _RecoFilterChip.
///     No Flutter FilterChip (theme-bleed risk, Lesson 9).
///   Transaction rows — each one is a TransactionCard, which owns its own
///     HoverListItem(size: HoverSize.subtle) internally; this file only
///     handles entrance stagger and the empty/load-more states.
///
/// Entrance: HoverEntrance(index: i) per row, separate widget from the
///   hover scale that TransactionCard owns internally (Lesson — entrance
///   and hover never share a Transform).
///
/// Open item (per UI Enhancement Phase Summary §9.1): "Load more" entrance
///   behavior for Wallet/Audit was left unresolved between instant append
///   and staggered replay. This implementation uses INSTANT APPEND —
///   newly-loaded rows are NOT wrapped in a fresh HoverEntrance cascade,
///   they simply appear. Rationale: a staggered replay on every "Load More"
///   tap would re-animate only the *new* page's rows (existing rows keep
///   playOnce=true and won't replay), which reads fine, but instant append
///   avoids a population of HoverEntrance controllers being created on
///   every pagination click for a list that may grow to hundreds of rows.
///   If staggered replay is preferred instead, wrap each newly-appended
///   TransactionCard in HoverEntrance(index: i, playOnce: true) using an
///   index relative to the newly-loaded page, not the full list — flag
///   this for confirmation before Phase 11 (Audit Trail) reuses the same
///   pattern, since Audit Trail has the identical open item.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../providers/wallet_provider.dart';
import 'transaction_card.dart';

class TransactionList extends ConsumerWidget {
  const TransactionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);

    return walletAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.wallet),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppTheme.danger)),
      ),
      data: (state) {
        final txnList = state.transactionList;
        if (txnList == null) {
          return const Center(
            child: Text('No transaction data',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Transaction History',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${txnList.totalCount} total',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // Summary chips — static display, no hover
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SummaryChip(
                        label:
                            '+\$${txnList.totalCredits.toStringAsFixed(0)}',
                        color: AppTheme.success,
                      ),
                      const SizedBox(width: 8),
                      _SummaryChip(
                        label:
                            '-\$${txnList.totalDebits.toStringAsFixed(0)}',
                        color: AppTheme.danger,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Filter chips ────────────────────────────────────────────
            _FilterBar(currentFilter: state.txnTypeFilter),
            const SizedBox(height: 12),

            // ── Transactions ────────────────────────────────────────────
            if (txnList.transactions.isEmpty)
              _EmptyState(filter: state.txnTypeFilter)
            else ...[
              ...txnList.transactions.asMap().entries.map(
                    (e) => HoverEntrance(
                      index: e.key,
                      child: TransactionCard(transaction: e.value),
                    ),
                  ),

              // Load more — instant append, see file header note.
              if (state.hasMorePages)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: state.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.wallet),
                          )
                        : HoverButton(
                            label: 'Load More',
                            icon: Icons.expand_more_rounded,
                            outlined: true,
                            expand: false,
                            onPressed: () => ref
                                .read(walletProvider.notifier)
                                .loadMoreTransactions(),
                          ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// _FilterBar — custom chips, small/isolated/horizontal-scroll shape.
// ════════════════════════════════════════════════════════════════════════

class _FilterBar extends ConsumerWidget {
  final String? currentFilter;

  const _FilterBar({this.currentFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = [
      (null, 'All', AppTheme.wallet),
      ('DEBIT', 'Debits', AppTheme.danger),
      ('CREDIT', 'Credits', AppTheme.success),
      ('REFUND', 'Refunds', AppTheme.brandIndigo),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isActive = currentFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _TxnFilterChip(
              label: f.$2,
              color: f.$3,
              isSelected: isActive,
              onTap: () =>
                  ref.read(walletProvider.notifier).filterByType(f.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TxnFilterChip extends StatefulWidget {
  const _TxnFilterChip({
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
  State<_TxnFilterChip> createState() => _TxnFilterChipState();
}

class _TxnFilterChipState extends State<_TxnFilterChip> {
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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: active
                  ? widget.color.withValues(alpha: 0.15)
                  : AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(AppTheme.radiusBadges),
              border: Border.all(
                color: active ? widget.color : AppTheme.borderColor,
                width: active ? 1.5 : 1,
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.28),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color:
                    active ? widget.color : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight:
                    widget.isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// _SummaryChip — static display only, intentionally not hoverable.
// ════════════════════════════════════════════════════════════════════════

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// _EmptyState
// ════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String? filter;

  const _EmptyState({this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_rounded,
                size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              filter != null
                  ? 'No ${filter!.toLowerCase()} transactions'
                  : 'No transactions yet',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}