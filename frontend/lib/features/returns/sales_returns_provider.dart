import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'sales_return_model.dart';

final salesReturnsProvider = FutureProvider.autoDispose<List<SalesReturn>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<SalesReturn>>(
    '/api/sales-returns',
    (json) => (json as List).map((e) => SalesReturn.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
