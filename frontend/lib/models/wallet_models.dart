/// Wallet Models — Wallet & Transaction responses
library;

// ============================================================================
// Wallet Response Model
// ============================================================================

class WalletResponse {
  final int walletId;
  final int userId;
  final String currencyCode;
  final String currencySymbol;
  final double balance;
  final String walletType; // PRIMARY, SAVINGS, FOREIGN
  final bool isActive;
  final DateTime createdAt;

  WalletResponse({
    required this.walletId,
    required this.userId,
    required this.currencyCode,
    required this.currencySymbol,
    required this.balance,
    required this.walletType,
    required this.isActive,
    required this.createdAt,
  });

  factory WalletResponse.fromJson(Map<String, dynamic> json) {
    return WalletResponse(
      walletId: json['wallet_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      currencyCode: (json['currency_code'] ?? 'USD').toString().trim(),
      currencySymbol: (json['currency_symbol'] ?? '\$').toString().trim(),
      balance: (json['balance'] ?? 0).toDouble(),
      walletType: json['wallet_type'] ?? 'PRIMARY',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  String get walletTypeLabel {
    switch (walletType) {
      case 'PRIMARY':
        return 'Primary';
      case 'SAVINGS':
        return 'Savings';
      case 'FOREIGN':
        return 'Foreign';
      default:
        return walletType;
    }
  }

  String get formattedBalance => '$currencySymbol${balance.toStringAsFixed(2)}';
}

// ============================================================================
// Wallet List Response Model
// ============================================================================

class WalletListResponse {
  final List<WalletResponse> wallets;
  final double totalBalanceUsd;
  final double primaryWalletBalance;

  WalletListResponse({
    required this.wallets,
    required this.totalBalanceUsd,
    required this.primaryWalletBalance,
  });

  factory WalletListResponse.fromJson(Map<String, dynamic> json) {
    final wallets = json['wallets'] as List? ?? [];
    return WalletListResponse(
      wallets: wallets.map((w) => WalletResponse.fromJson(w)).toList(),
      totalBalanceUsd: (json['total_balance_usd'] ?? 0).toDouble(),
      primaryWalletBalance: (json['primary_wallet_balance'] ?? 0).toDouble(),
    );
  }
}

// ============================================================================
// Transaction Response Model
// ============================================================================

class TransactionResponse {
  final int txnId;
  final int userId;
  final int walletId;
  final String? walletCurrency;
  final String? categoryName;
  final String? subscriptionName;
  final double amount;
  final double? amountUsd;
  final String txnType; // DEBIT, CREDIT, REFUND
  final String? description;
  final DateTime txnDate;
  final bool isRecurring;
  final bool isAnomaly;

  TransactionResponse({
    required this.txnId,
    required this.userId,
    required this.walletId,
    this.walletCurrency,
    this.categoryName,
    this.subscriptionName,
    required this.amount,
    this.amountUsd,
    required this.txnType,
    this.description,
    required this.txnDate,
    required this.isRecurring,
    required this.isAnomaly,
  });

  factory TransactionResponse.fromJson(Map<String, dynamic> json) {
    return TransactionResponse(
      txnId: json['txn_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      walletId: json['wallet_id'] ?? 0,
      walletCurrency: json['wallet_currency'],
      categoryName: json['category_name'],
      subscriptionName: json['subscription_name'],
      amount: (json['amount'] ?? 0).toDouble(),
      amountUsd: json['amount_usd'] != null
          ? (json['amount_usd']).toDouble()
          : null,
      txnType: json['txn_type'] ?? 'DEBIT',
      description: json['description'],
      txnDate: json['txn_date'] != null
          ? DateTime.parse(json['txn_date'])
          : DateTime.now(),
      isRecurring: json['is_recurring'] ?? false,
      isAnomaly: json['is_anomaly'] ?? false,
    );
  }

  bool get isDebit => txnType == 'DEBIT';
  bool get isCredit => txnType == 'CREDIT' || txnType == 'REFUND';

  String get symbol => walletCurrency == 'PKR'
      ? 'Rs'
      : walletCurrency == 'EUR'
          ? '€'
          : walletCurrency == 'GBP'
              ? '£'
              : '\$';

  String get formattedAmount =>
      '${isCredit ? '+' : '-'}$symbol${amount.toStringAsFixed(2)}';

  String get txnTypeLabel {
    switch (txnType) {
      case 'DEBIT':
        return 'Debit';
      case 'CREDIT':
        return 'Credit';
      case 'REFUND':
        return 'Refund';
      default:
        return txnType;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(txnDate);
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String get formattedDate {
    return '${txnDate.day}/${txnDate.month}/${txnDate.year}';
  }
}

// ============================================================================
// Transaction List Response Model
// ============================================================================

class TransactionListResponse {
  final List<TransactionResponse> transactions;
  final int totalCount;
  final double totalDebits;
  final double totalCredits;
  final int page;
  final int pageSize;

  TransactionListResponse({
    required this.transactions,
    required this.totalCount,
    required this.totalDebits,
    required this.totalCredits,
    required this.page,
    required this.pageSize,
  });

  factory TransactionListResponse.fromJson(Map<String, dynamic> json) {
    final txns = json['transactions'] as List? ?? [];
    return TransactionListResponse(
      transactions: txns.map((t) => TransactionResponse.fromJson(t)).toList(),
      totalCount: json['total_count'] ?? 0,
      totalDebits: (json['total_debits'] ?? 0).toDouble(),
      totalCredits: (json['total_credits'] ?? 0).toDouble(),
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 20,
    );
  }
}

// ============================================================================
// Monthly Spending Response Model
// ============================================================================

class MonthlySpendingResponse {
  final String month;
  final double totalSpent;
  final double subscriptionSpent;
  final double otherSpent;
  final int transactionCount;

  MonthlySpendingResponse({
    required this.month,
    required this.totalSpent,
    required this.subscriptionSpent,
    required this.otherSpent,
    required this.transactionCount,
  });

  factory MonthlySpendingResponse.fromJson(Map<String, dynamic> json) {
    return MonthlySpendingResponse(
      month: json['month'] ?? '',
      totalSpent: (json['total_spent'] ?? 0).toDouble(),
      subscriptionSpent: (json['subscription_spent'] ?? 0).toDouble(),
      otherSpent: (json['other_spent'] ?? 0).toDouble(),
      transactionCount: json['transaction_count'] ?? 0,
    );
  }

  /// Returns month label like "Jan 2026"
  String get monthLabel {
    if (month.isEmpty) return '';
    final parts = month.split('-');
    if (parts.length < 2) return month;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final idx = int.tryParse(parts[1]);
    if (idx == null || idx < 1 || idx > 12) return month;
    return '${months[idx - 1]} ${parts[0]}';
  }
}
