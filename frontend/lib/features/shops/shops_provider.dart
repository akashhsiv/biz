import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'shop_model.dart';

/// GET /api/shops — shops the logged-in user belongs to (via UserShopRole). Re-fetched whenever
/// invalidated (e.g. after login) rather than cached across sessions.
final shopsProvider = FutureProvider.autoDispose<List<Shop>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Shop>>(
    '/api/shops',
    (json) => (json as List).map((e) => Shop.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

/// Tracks which shop is currently active for this session. The backend keeps the active shop tied
/// to the session token itself (POST /api/auth/select-shop looks the caller's token up by hash and
/// stamps the shop on that session server-side) — there is no per-request shop header to send, and
/// the bearer token doesn't change. The client only needs to remember the chosen shop id locally
/// (to skip the picker next time and to know what to show as "current"), and to fold the returned
/// role/permissions into AuthState since they now reflect the selected shop rather than the
/// legacy per-user RoleId.
class SelectedShopController extends StateNotifier<String?> {
  final Ref _ref;

  SelectedShopController(this._ref) : super(null);

  Future<void> restoreFromCache() async {
    final storage = _ref.read(appStorageProvider);
    state = await storage.getSelectedShopId();
  }

  Future<ApiResult<bool>> selectShop(String shopId) async {
    final api = _ref.read(apiClientProvider);
    final storage = _ref.read(appStorageProvider);

    final result = await api.post<Map<String, dynamic>>(
      '/api/auth/select-shop',
      (json) => json as Map<String, dynamic>,
      body: {'shopId': shopId},
    );

    switch (result) {
      case ApiSuccess(data: final data):
        await storage.saveSelectedShopId(shopId);
        state = shopId;

        // Reflect the shop-scoped role/permissions returned by select-shop into AuthState and the
        // cached profile, the same way login() does — every permission check in the app reads from
        // AuthState, so this must be updated for the new shop's access to actually take effect.
        final roleName = data['roleName'] as String;
        final permissions = Set<String>.from(data['permissions'] as List);
        final auth = _ref.read(authControllerProvider.notifier);
        auth.applyShopRole(roleName, permissions);

        return const ApiSuccess(true);
      case ApiFailure(statusCode: final code, message: final msg):
        return ApiFailure(code, msg);
      case ApiNetworkError(message: final msg):
        return ApiNetworkError(msg);
    }
  }

  Future<void> clear() async {
    final storage = _ref.read(appStorageProvider);
    await storage.clearSelectedShopId();
    state = null;
  }
}

final selectedShopControllerProvider = StateNotifierProvider<SelectedShopController, String?>((ref) {
  return SelectedShopController(ref);
});
