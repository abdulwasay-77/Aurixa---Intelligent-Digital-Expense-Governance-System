/// Subscription Models
library;

// ============================================================================
// Response Models
// ============================================================================

class SubscriptionResponse {
  final int subId;
  final int userId;
  final int? vendorId;
  final String? vendorName;
  final int categoryId;
  final String categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final String currencyCode;
  final String currencySymbol;
  final String serviceName;
  final double billingAmount;
  final String billingCycle;
  final DateTime nextBillingDate;
  final DateTime startDate;
  final int usageScore;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final double? totalSpent;
  final int? upcomingBillingCount;

  SubscriptionResponse({
    required this.subId,
    required this.userId,
    this.vendorId,
    this.vendorName,
    required this.categoryId,
    required this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    required this.currencyCode,
    required this.currencySymbol,
    required this.serviceName,
    required this.billingAmount,
    required this.billingCycle,
    required this.nextBillingDate,
    required this.startDate,
    required this.usageScore,
    required this.status,
    this.notes,
    required this.createdAt,
    this.totalSpent,
    this.upcomingBillingCount,
  });

  factory SubscriptionResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionResponse(
      subId: json['sub_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      vendorId: json['vendor_id'],
      vendorName: json['vendor_name'],
      categoryId: json['category_id'] ?? 0,
      categoryName: json['category_name'] ?? '',
      categoryIcon: json['category_icon'],
      categoryColor: json['category_color'],
      currencyCode: json['currency_code'] ?? 'USD',
      currencySymbol: json['currency_symbol'] ?? '\$',
      serviceName: json['service_name'] ?? '',
      billingAmount: (json['billing_amount'] ?? 0).toDouble(),
      billingCycle: json['billing_cycle'] ?? 'MONTHLY',
      nextBillingDate: json['next_billing_date'] != null
          ? DateTime.parse(json['next_billing_date'])
          : DateTime.now(),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : DateTime.now(),
      usageScore: json['usage_score'] ?? 5,
      status: json['status'] ?? 'ACTIVE',
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      totalSpent: json['total_spent']?.toDouble(),
      upcomingBillingCount: json['upcoming_billing_count'],
    );
  }

  bool get isActive => status == 'ACTIVE';
  bool get isCancelled => status == 'CANCELLED';
  bool get isPaused => status == 'PAUSED';

  String get cycleLabel {
    switch (billingCycle) {
      case 'MONTHLY': return 'month';
      case 'YEARLY': return 'year';
      case 'WEEKLY': return 'week';
      case 'QUARTERLY': return 'quarter';
      default: return billingCycle.toLowerCase();
    }
  }

  double get monthlyEquivalent {
    switch (billingCycle) {
      case 'YEARLY': return billingAmount / 12;
      case 'QUARTERLY': return billingAmount / 3;
      case 'WEEKLY': return billingAmount * 4.33;
      default: return billingAmount;
    }
  }
}

// ============================================================================
// Category Summary Model
// ============================================================================

class CategorySummary {
  final String categoryName;
  final int subscriptionCount;
  final double totalMonthly;

  CategorySummary({
    required this.categoryName,
    required this.subscriptionCount,
    required this.totalMonthly,
  });

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      categoryName: json['category_name'] ?? '',
      subscriptionCount: json['subscription_count'] ?? 0,
      totalMonthly: (json['total_monthly'] ?? 0).toDouble(),
    );
  }
}

// ============================================================================
// Request Models
// ============================================================================

class CreateSubscriptionRequest {
  final String? vendorName;
  final String categoryName;
  final String serviceName;
  final double billingAmount;
  final String billingCycle;
  final DateTime nextBillingDate;
  final DateTime startDate;
  final String currencyCode;
  final int usageScore;
  final String? notes;

  CreateSubscriptionRequest({
    this.vendorName,
    required this.categoryName,
    required this.serviceName,
    required this.billingAmount,
    required this.billingCycle,
    required this.nextBillingDate,
    required this.startDate,
    this.currencyCode = 'USD',
    this.usageScore = 5,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'vendor_name': vendorName,
        'category_name': categoryName,
        'service_name': serviceName,
        'billing_amount': billingAmount,
        'billing_cycle': billingCycle,
        'next_billing_date':
            nextBillingDate.toIso8601String().split('T').first,
        'start_date': startDate.toIso8601String().split('T').first,
        'currency_code': currencyCode,
        'usage_score': usageScore,
        'notes': notes,
      };
}

class UpdateSubscriptionRequest {
  final String? vendorName;
  final String? categoryName;
  final String? serviceName;
  final double? billingAmount;
  final String? billingCycle;
  final DateTime? nextBillingDate;
  final int? usageScore;
  final String? status;
  final String? notes;

  UpdateSubscriptionRequest({
    this.vendorName,
    this.categoryName,
    this.serviceName,
    this.billingAmount,
    this.billingCycle,
    this.nextBillingDate,
    this.usageScore,
    this.status,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (vendorName != null) map['vendor_name'] = vendorName;
    if (categoryName != null) map['category_name'] = categoryName;
    if (serviceName != null) map['service_name'] = serviceName;
    if (billingAmount != null) map['billing_amount'] = billingAmount;
    if (billingCycle != null) map['billing_cycle'] = billingCycle;
    if (nextBillingDate != null) {
      map['next_billing_date'] =
          nextBillingDate!.toIso8601String().split('T').first;
    }
    if (usageScore != null) map['usage_score'] = usageScore;
    if (status != null) map['status'] = status;
    if (notes != null) map['notes'] = notes;
    return map;
  }
}

// ============================================================================
// Idle Detection Model
// ============================================================================

class IdleSubscriptionResponse {
  final int subId;
  final String serviceName;
  final double billingAmount;
  final int usageScore;
  final int? daysSinceUse;
  final String recommendation;

  IdleSubscriptionResponse({
    required this.subId,
    required this.serviceName,
    required this.billingAmount,
    required this.usageScore,
    this.daysSinceUse,
    required this.recommendation,
  });

  factory IdleSubscriptionResponse.fromJson(Map<String, dynamic> json) {
    return IdleSubscriptionResponse(
      subId: json['sub_id'] ?? 0,
      serviceName: json['service_name'] ?? '',
      billingAmount: (json['billing_amount'] ?? 0).toDouble(),
      usageScore: json['usage_score'] ?? 5,
      daysSinceUse: json['days_since_use'],
      recommendation: json['recommendation'] ?? '',
    );
  }
}