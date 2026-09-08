import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'category_model.dart';

/// Every active Item Category for this shop — always includes the auto-seeded "Cash Bill"
/// category plus whatever the Shop Admin has created via category management. Drives the
/// per-category sidebar navigation (one entry per category).
final categoriesProvider = FutureProvider.autoDispose<List<ItemCategory>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<ItemCategory>>(
    '/api/item-categories',
    (json) => (json as List).map((e) => ItemCategory.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

Future<String?> createCategory(WidgetRef ref, String name) async {
  final api = ref.read(apiClientProvider);
  final result = await api.post<Map<String, dynamic>>(
    '/api/item-categories',
    (json) => json as Map<String, dynamic>,
    body: {'name': name},
  );

  return switch (result) {
    ApiSuccess() => null,
    ApiFailure(message: final msg) => msg,
    ApiNetworkError(message: final msg) => 'Could not reach the Host: $msg',
  };
}
