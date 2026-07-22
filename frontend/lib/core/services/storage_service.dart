/// Secure Local Storage Service using SharedPreferences
library;

import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token Storage
  static Future<void> setAccessToken(String token) async {
    await _prefs?.setString(AppConstants.storageAccessToken, token);
  }

  static String? getAccessToken() {
    return _prefs?.getString(AppConstants.storageAccessToken);
  }

  static Future<void> setRefreshToken(String token) async {
    await _prefs?.setString(AppConstants.storageRefreshToken, token);
  }

  static String? getRefreshToken() {
    return _prefs?.getString(AppConstants.storageRefreshToken);
  }

  // User Info Storage
  static Future<void> setUserId(int id) async {
    await _prefs?.setInt(AppConstants.storageUserId, id);
  }

  static int? getUserId() {
    return _prefs?.getInt(AppConstants.storageUserId);
  }

  static Future<void> setUserEmail(String email) async {
    await _prefs?.setString(AppConstants.storageUserEmail, email);
  }

  static String? getUserEmail() {
    return _prefs?.getString(AppConstants.storageUserEmail);
  }

  static Future<void> setUserFullName(String name) async {
    await _prefs?.setString(AppConstants.storageUserFullName, name);
  }

  static String? getUserFullName() {
    return _prefs?.getString(AppConstants.storageUserFullName);
  }

  // Clear all data (logout)
  static Future<void> clearAll() async {
    await _prefs?.remove(AppConstants.storageAccessToken);
    await _prefs?.remove(AppConstants.storageRefreshToken);
    await _prefs?.remove(AppConstants.storageUserId);
    await _prefs?.remove(AppConstants.storageUserEmail);
    await _prefs?.remove(AppConstants.storageUserFullName);
  }

  // Check if user is logged in
  static bool isLoggedIn() {
    return getAccessToken() != null && getAccessToken()!.isNotEmpty;
  }
}