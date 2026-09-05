import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'user_model.dart';

final usersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<AppUser>>(
    '/api/users',
    (json) => (json as List).map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

final rolesProvider = FutureProvider.autoDispose<List<AppRole>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<AppRole>>(
    '/api/roles',
    (json) => (json as List).map((e) => AppRole.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

final permissionsCatalogProvider = FutureProvider.autoDispose<List<AppPermission>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<AppPermission>>(
    '/api/permissions',
    (json) => (json as List).map((e) => AppPermission.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
