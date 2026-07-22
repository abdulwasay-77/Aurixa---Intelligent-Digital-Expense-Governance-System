/// API Service with Dio client and JWT interceptor
/// PERF FIX: Interceptors now registered ONCE via _initInterceptors(),
/// not cleared and re-added on every single API call.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import 'storage_service.dart';

class ApiService {
  static final Dio _dio = _createDio();

  /// Creates and fully configures the Dio instance once.
  /// Called only at class-load time via the static field initializer.
  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        // PERF FIX: 30s felt frozen. 10s is plenty for a local backend.
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // PERF FIX: Interceptor registered ONCE here, never again.
    // Old code called _addInterceptors() (clear + re-add) on every
    // single ApiService.get/post/put/delete call — wasteful.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = StorageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // PERF FIX: replaced print() with debugPrint() — print()
            // flushes synchronously and can cause frame drops in debug mode.
            debugPrint('⚠️ Token expired. Please login again.');
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  // ==========================================================================
  // HTTP METHODS
  // ==========================================================================

  static Future<Response> get(String endpoint) async {
    return await _dio.get(endpoint);
  }

  static Future<Response> post(String endpoint, {dynamic data}) async {
    return await _dio.post(endpoint, data: data);
  }

  static Future<Response> put(String endpoint, {dynamic data}) async {
    return await _dio.put(endpoint, data: data);
  }

  // ==========================================================================
  // FIX: Added PATCH method for updating usage scores
  // ==========================================================================
  static Future<Response> patch(String endpoint, {dynamic data}) async {
    return await _dio.patch(endpoint, data: data);
  }

  static Future<Response> delete(String endpoint) async {
    return await _dio.delete(endpoint);
  }
}