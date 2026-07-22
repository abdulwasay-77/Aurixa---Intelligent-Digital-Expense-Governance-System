/// Wallet Provider — AsyncNotifier state management for WalletScreen
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/api_service.dart';
import '../models/wallet_models.dart';

// ============================================================================
// State
// ============================================================================

class WalletState {
  final WalletListResponse? walletList;
  final TransactionListResponse? transactionList;
  final List<MonthlySpendingResponse> monthlySpending;
  final bool isLoading;
  final String? errorMessage;

  // Pagination
  final int currentPage;
  final bool hasMorePages;

  // Filter
  final String? txnTypeFilter; // DEBIT, CREDIT, REFUND, null = all

  const WalletState({
    this.walletList,
    this.transactionList,
    this.monthlySpending = const [],
    this.isLoading = false,
    this.errorMessage,
    this.currentPage = 1,
    this.hasMorePages = false,
    this.txnTypeFilter,
  });

  WalletState copyWith({
    WalletListResponse? walletList,
    TransactionListResponse? transactionList,
    List<MonthlySpendingResponse>? monthlySpending,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    int? currentPage,
    bool? hasMorePages,
    String? txnTypeFilter,
    bool clearFilter = false,
  }) {
    return WalletState(
      walletList: walletList ?? this.walletList,
      transactionList: transactionList ?? this.transactionList,
      monthlySpending: monthlySpending ?? this.monthlySpending,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentPage: currentPage ?? this.currentPage,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      txnTypeFilter:
          clearFilter ? null : (txnTypeFilter ?? this.txnTypeFilter),
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

class WalletNotifier extends AsyncNotifier<WalletState> {
  static const int _pageSize = 15;

  @override
  Future<WalletState> build() async {
    return await _fetchAll(page: 1, filter: null);
  }

  // --------------------------------------------------------------------------
  // Private helpers
  // --------------------------------------------------------------------------

  /// Backend uses limit/offset (not page/page_size).
  /// page=1 => offset=0, page=2 => offset=_pageSize, etc.
  Future<WalletState> _fetchAll({
    required int page,
    required String? filter,
  }) async {
    try {
      // 1. Wallets
      final walletRes = await ApiService.get('/api/wallet');
      final walletList =
          WalletListResponse.fromJson(walletRes.data as Map<String, dynamic>);

      // 2. Transactions — backend uses limit & offset
      final offset = (page - 1) * _pageSize;
      final filterParam = filter != null ? '&txn_type=$filter' : '';
      final txnRes = await ApiService.get(
        '/api/wallet/transactions?limit=$_pageSize&offset=$offset$filterParam',
      );
      final txnList = TransactionListResponse.fromJson(
          txnRes.data as Map<String, dynamic>);

      final hasMore = (offset + _pageSize) < txnList.totalCount;

      // 3. Monthly spending
      final spendRes =
          await ApiService.get('/api/wallet/spending/monthly?months=6');
      final spending = (spendRes.data as List? ?? [])
          .map((e) => MonthlySpendingResponse.fromJson(e))
          .toList();

      return WalletState(
        walletList: walletList,
        transactionList: txnList,
        monthlySpending: spending,
        currentPage: page,
        hasMorePages: hasMore,
        txnTypeFilter: filter,
      );
    } catch (e) {
      throw Exception('Failed to load wallet data: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Public actions
  // --------------------------------------------------------------------------

  Future<void> refresh() async {
    final currentFilter =
        state.valueOrNull?.txnTypeFilter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => _fetchAll(page: 1, filter: currentFilter));
  }

  Future<void> filterByType(String? type) async {
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => _fetchAll(page: 1, filter: type));
  }

  Future<void> loadMoreTransactions() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMorePages || current.isLoading) return;

    final nextPage = current.currentPage + 1;
    state = AsyncData(current.copyWith(isLoading: true));

    try {
      final offset = nextPage * _pageSize;
      final filterParam = current.txnTypeFilter != null
          ? '&txn_type=${current.txnTypeFilter}'
          : '';
      final txnRes = await ApiService.get(
        '/api/wallet/transactions?limit=$_pageSize&offset=$offset$filterParam',
      );
      final newTxns = TransactionListResponse.fromJson(
          txnRes.data as Map<String, dynamic>);


        // Append transactions
      final List<TransactionResponse> combined = [
        ...(current.transactionList?.transactions ?? <TransactionResponse>[]),
        ...newTxns.transactions,
      ];

      final merged = TransactionListResponse(
        transactions: combined,
        totalCount: newTxns.totalCount,
        totalDebits: newTxns.totalDebits,
        totalCredits: newTxns.totalCredits,
        page: nextPage,
        pageSize: _pageSize,
      );

      final hasMore = (offset + _pageSize) < newTxns.totalCount;
      state = AsyncData(current.copyWith(
        transactionList: merged,
        currentPage: nextPage,
        hasMorePages: hasMore,
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(
          current.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Top up a wallet — POST /api/wallet/topup
  Future<bool> topUpWallet({
    required int walletId,
    required double amount,
    required String? paymentMethod,
    required String? description,
  }) async {
    try {
      await ApiService.post('/api/wallet/topup', data: {
        'wallet_id': walletId,
        'amount': amount,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (description != null) 'description': description,
      });
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Transfer between wallets — POST /api/wallet/transfer
  Future<String?> transferBetweenWallets({
    required int fromWalletId,
    required int toWalletId,
    required double amount,
    String? description,
  }) async {
    try {
      await ApiService.post('/api/wallet/transfer', data: {
        'from_wallet_id': fromWalletId,
        'to_wallet_id': toWalletId,
        'amount': amount,
        if (description != null) 'description': description,
      });
      await refresh();
      return null; // null = success
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Insufficient')) return 'Insufficient balance';
      if (msg.contains('not found')) return 'Wallet not found';
      return 'Transfer failed. Please try again.';
    }
  }

  /// Create a new wallet — POST /api/wallet
  Future<bool> createWallet({
    required String currencyCode,
    required String walletType,
  }) async {
    try {
      await ApiService.post('/api/wallet', data: {
        'currency_code': currencyCode,
        'wallet_type': walletType,
        'initial_balance': 0,
      });
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ============================================================================
// Provider
// ============================================================================

final walletProvider =
    AsyncNotifierProvider<WalletNotifier, WalletState>(WalletNotifier.new);
