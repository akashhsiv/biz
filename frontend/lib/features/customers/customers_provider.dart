import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'customer_model.dart';

final customersProvider = FutureProvider.autoDispose<List<Customer>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Customer>>(
    '/api/customers',
    (json) => (json as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
