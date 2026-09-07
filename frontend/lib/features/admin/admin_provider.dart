import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'shop_model.dart';

/// Lists every shop in the system — super-admin-only (`GET api/admin/shops`), not scoped to any
/// one shop the way every other list provider in the app is.
final adminShopsProvider = FutureProvider.autoDispose<List<Shop>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Shop>>(
    '/api/admin/shops',
    (json) => (json as List).map((e) => Shop.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

/// Thin wrappers around the two admin write endpoints — kept here rather than inline in the screen
/// so the screen only deals with UI state, matching the customers/staff provider split.
class AdminActions {
  final Ref ref;
  AdminActions(this.ref);

  Future<ApiResult<Shop>> createShop({
    required String name,
    String? gstin,
    String? address,
    String? contactNumber,
  }) {
    final api = ref.read(apiClientProvider);
    return api.post<Shop>(
      '/api/admin/shops',
      (json) => Shop.fromJson(json as Map<String, dynamic>),
      body: {
        'name': name,
        'gstin': gstin,
        'address': address,
        'contactNumber': contactNumber,
      },
    );
  }

  Future<ApiResult<ShopAdminCreationResult>> createShopAdmin({
    required String shopId,
    required String username,
    required String fullName,
    String? password,
  }) {
    final api = ref.read(apiClientProvider);
    return api.post<ShopAdminCreationResult>(
      '/api/admin/shops/$shopId/admins',
      (json) => ShopAdminCreationResult.fromJson(json as Map<String, dynamic>),
      body: {
        'username': username,
        'fullName': fullName,
        'password': password,
      },
    );
  }
}

final adminActionsProvider = Provider<AdminActions>((ref) => AdminActions(ref));
