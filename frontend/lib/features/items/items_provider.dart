import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'item_model.dart';

final itemsProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Item>>(
    '/api/items',
    (json) => (json as List).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
