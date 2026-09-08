import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'brand_model.dart';

/// All active Brands, optionally scoped to a Category — pass null for every active Brand.
final brandsProvider = FutureProvider.autoDispose.family<List<Brand>, String?>((ref, categoryId) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Brand>>(
    '/api/brands',
    (json) => (json as List).map((e) => Brand.fromJson(e as Map<String, dynamic>)).toList(),
    query: categoryId == null ? null : {'categoryId': categoryId},
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

/// Brands a given Vendor (Supplier) is linked to supply — feeds the Vendor → Brand cascade on the
/// Purchase create flow. Family key is the supplierId; a null/empty id yields an empty list.
final vendorBrandsProvider = FutureProvider.autoDispose.family<List<VendorBrand>, String?>((ref, supplierId) async {
  if (supplierId == null || supplierId.isEmpty) return [];

  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<VendorBrand>>(
    '/api/suppliers/$supplierId/brands',
    (json) => (json as List).map((e) => VendorBrand.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

/// Links a Brand to a Vendor (Supplier) so it becomes purchasable from them. Returns an error
/// message on failure, or null on success.
Future<String?> linkVendorBrand(WidgetRef ref, String supplierId, String brandId) async {
  final api = ref.read(apiClientProvider);
  final result = await api.post<Map<String, dynamic>>(
    '/api/suppliers/$supplierId/brands',
    (json) => json as Map<String, dynamic>,
    body: {'brandId': brandId},
  );

  return switch (result) {
    ApiSuccess() => null,
    ApiFailure(message: final msg) => msg,
    ApiNetworkError(message: final msg) => 'Could not reach the Host: $msg',
  };
}

/// Removes a Brand link from a Vendor (Supplier). Returns an error message on failure, or null on
/// success.
Future<String?> unlinkVendorBrand(WidgetRef ref, String supplierId, String brandId) async {
  final api = ref.read(apiClientProvider);
  final result = await api.delete<void>('/api/suppliers/$supplierId/brands/$brandId', (_) {});

  return switch (result) {
    ApiSuccess() => null,
    ApiFailure(message: final msg) => msg,
    ApiNetworkError(message: final msg) => 'Could not reach the Host: $msg',
  };
}

/// Creates a new Brand under a Category. Returns the created Brand's id on success, or null and
/// sets [errorOut] on failure.
Future<Brand?> createBrand(WidgetRef ref, String name, String categoryId, {void Function(String)? onError}) async {
  final api = ref.read(apiClientProvider);
  final result = await api.post<Brand>(
    '/api/brands',
    (json) => Brand.fromJson(json as Map<String, dynamic>),
    body: {'name': name, 'categoryId': categoryId},
  );

  switch (result) {
    case ApiSuccess(data: final data):
      return data;
    case ApiFailure(message: final msg):
      onError?.call(msg);
      return null;
    case ApiNetworkError(message: final msg):
      onError?.call('Could not reach the Host: $msg');
      return null;
  }
}
