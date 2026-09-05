import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'stock_model.dart';

final stockLevelsProvider = FutureProvider.autoDispose<List<StockLevel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<StockLevel>>(
    '/api/stock',
    (json) => (json as List).map((e) => StockLevel.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

final stockMovementsProvider = FutureProvider.autoDispose.family<List<StockMovement>, String?>((ref, itemId) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<StockMovement>>(
    '/api/stock/movements',
    (json) => (json as List).map((e) => StockMovement.fromJson(e as Map<String, dynamic>)).toList(),
    query: itemId == null ? null : {'itemId': itemId},
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
