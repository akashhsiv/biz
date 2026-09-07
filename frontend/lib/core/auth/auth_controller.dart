import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_result.dart';
import '../providers.dart';
import '../push/push_registration.dart';
import '../storage/app_storage.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  final ApiClient _api;
  final AppStorage _storage;

  AuthController(this._api, this._storage) : super(AuthState.initial);

  /// Called once at app startup to restore a cached session without a network round-trip.
  Future<void> restoreFromCache() async {
    final token = await _storage.getToken();
    final profile = await _storage.getProfile();
    if (token == null || profile == null) {
      debugPrint('[AuthController] restoreFromCache: no cached token/profile, staying logged out');
      return;
    }

    final permissions = Set<String>.from(profile['permissions'] as List);
    debugPrint('[AuthController] restoreFromCache: user=${profile['username']} role=${profile['roleName']} permissions=$permissions');

    state = AuthState(
      isAuthenticated: true,
      userId: profile['userId'] as String,
      username: profile['username'] as String,
      fullName: profile['fullName'] as String,
      roleName: profile['roleName'] as String,
      permissions: permissions,
      isSuperAdmin: profile['isSuperAdmin'] as bool? ?? false,
    );
  }

  Future<ApiResult<bool>> login(String username, String password) async {
    state = state.copyWith(isLoading: true);

    final result = await _api.post<Map<String, dynamic>>(
      '/api/auth/login',
      (json) => json as Map<String, dynamic>,
      body: {'username': username, 'password': password},
    );

    switch (result) {
      case ApiSuccess(data: final data):
        final token = data['token'] as String;
        await _storage.saveToken(token);
        await _storage.saveProfile(data);

        final permissions = Set<String>.from(data['permissions'] as List);
        debugPrint('[AuthController] login success: user=${data['username']} role=${data['roleName']} permissions=$permissions');

        state = AuthState(
          isAuthenticated: true,
          userId: data['userId'] as String,
          username: data['username'] as String,
          fullName: data['fullName'] as String,
          roleName: data['roleName'] as String,
          permissions: permissions,
          isSuperAdmin: data['isSuperAdmin'] as bool? ?? false,
        );

        // Fire-and-forget: registering a push token is never allowed to delay or fail login (see
        // registerDeviceTokenForPush's doc comment - it no-ops until Firebase is actually configured).
        unawaited(registerDeviceTokenForPush(_api));

        return const ApiSuccess(true);

      case ApiFailure(statusCode: final code, message: final msg):
        debugPrint('[AuthController] login failed: HTTP $code - $msg');
        state = state.copyWith(isLoading: false);
        return ApiFailure(code, msg);

      case ApiNetworkError(message: final msg):
        debugPrint('[AuthController] login network error: $msg');
        state = state.copyWith(isLoading: false);
        return ApiNetworkError(msg);
    }
  }

  /// Confirms the cached token restored by [restoreFromCache] is actually valid for whichever Host
  /// the app just connected to. The cache has no per-Host scoping, so a Slave that switches to a
  /// different Host (or reconnects after its session was revoked/expired) would otherwise land on
  /// Home optimistically and only discover the token is bad on the first real API call. Call this
  /// once a connection is confirmed, not from restoreFromCache itself, since there's no Host to
  /// validate against yet at raw app startup.
  Future<void> validateSession() async {
    if (!state.isAuthenticated) return;

    final result = await _api.get<void>('/api/auth/me', (_) {});
    if (result is ApiFailure<void> && result.statusCode == 401) {
      debugPrint('[AuthController] validateSession: cached session is not valid on this Host, logging out locally');
      await _storage.clearToken();
      await _storage.clearProfile();
      state = AuthState.initial;
    }
    // ApiNetworkError is left alone - an unreachable Host doesn't mean the token is invalid, just unconfirmed.
  }

  /// Folds the shop-scoped role/permissions returned by POST /api/auth/select-shop into the
  /// current session state and the cached profile (so a restart after picking a shop restores
  /// with that shop's access, not the stale pre-selection one).
  Future<void> applyShopRole(String roleName, Set<String> permissions) async {
    state = state.copyWith(roleName: roleName, permissions: permissions);

    final profile = await _storage.getProfile();
    if (profile != null) {
      await _storage.saveProfile({
        ...profile,
        'roleName': roleName,
        'permissions': permissions.toList(),
      });
    }
  }

  Future<void> logout() async {
    debugPrint('[AuthController] logout: user=${state.username}');
    await _api.post('/api/auth/logout', (_) => null);
    await _storage.clearToken();
    await _storage.clearProfile();
    await _storage.clearSelectedShopId();
    state = AuthState.initial;
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(apiClientProvider), ref.watch(appStorageProvider));
});
