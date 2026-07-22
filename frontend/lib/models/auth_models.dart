/// Authentication Models — Request/Response DTOs
library;

// ============================================================================
// Request Models
// ============================================================================

class RegisterRequest {
  final String email;
  final String password;
  final String fullName;
  final String? phone;
  final double monthlyIncome;
  final double savingTargetPct;
  final String riskTolerance;
  final String? lifestyleCategory;
  final String baseCurrencyCode;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    this.phone,
    required this.monthlyIncome,
    this.savingTargetPct = 20.0,
    this.riskTolerance = 'MEDIUM',
    this.lifestyleCategory,
    this.baseCurrencyCode = 'USD',
  });

  Map<String, dynamic> toJson() => {
        'email': email.trim().toLowerCase(),
        'password': password,
        'full_name': fullName.trim(),
        'phone': phone?.trim(),
        'monthly_income': monthlyIncome,
        'saving_target_pct': savingTargetPct,
        'risk_tolerance': riskTolerance,
        'lifestyle_category': lifestyleCategory,
        'base_currency_code': baseCurrencyCode,
      };
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email.trim().toLowerCase(),
        'password': password,
      };
}

// ============================================================================
// Response Models
// ============================================================================

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresInMinutes;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresInMinutes,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      expiresInMinutes: json['expires_in_minutes'] ?? 15,
    );
  }
}

class UserResponse {
  final int userId;
  final String email;
  final String fullName;
  final String? phone;
  final String status;
  final DateTime createdAt;
  final DateTime? lastLogin;

  UserResponse({
    required this.userId,
    required this.email,
    required this.fullName,
    this.phone,
    required this.status,
    required this.createdAt,
    this.lastLogin,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      userId: json['user_id'] ?? 0,
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'],
      status: json['status'] ?? 'ACTIVE',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
    );
  }
}

class MessageResponse {
  final String message;
  final bool success;

  MessageResponse({required this.message, this.success = true});

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(
      message: json['message'] ?? '',
      success: json['success'] ?? true,
    );
  }
}