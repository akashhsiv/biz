import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Host URL is just a connection preference (fine in plain prefs). The session token is a
/// bearer credential, so it lives in secure storage (Windows Credential Manager–backed) instead.
/// The profile cache lets the app restore its UI (name/role/permissions) without a network call
/// on launch; if the cached token turns out to be expired, the first real API call will 401 and
/// the app falls back to the login screen.
class AppStorage {
  static const _hostUrlKey = 'host_url';
  static const _tokenKey = 'session_token';
  static const _profileKey = 'session_profile';
  static const _shopIdKey = 'selected_shop_id';

  final _secure = const FlutterSecureStorage();

  Future<String?> getHostUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hostUrlKey);
  }

  Future<void> saveHostUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostUrlKey, url);
  }

  Future<String?> getToken() => _secure.read(key: _tokenKey);

  Future<void> saveToken(String token) => _secure.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _secure.delete(key: _tokenKey);

  Future<Map<String, dynamic>?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile));
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }

  /// Multi-shop rework: the currently selected shop is just a UI/session convenience (not a
  /// credential), so it lives alongside the host URL in plain prefs rather than secure storage.
  Future<String?> getSelectedShopId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shopIdKey);
  }

  Future<void> saveSelectedShopId(String shopId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shopIdKey, shopId);
  }

  Future<void> clearSelectedShopId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shopIdKey);
  }
}
