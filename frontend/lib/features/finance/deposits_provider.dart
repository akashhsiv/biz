import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'deposit_model.dart';

final depositsProvider = FutureProvider.autoDispose.family<List<Deposit>, String?>((ref, customerId) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Deposit>>(
    '/api/customer-deposits',
    (json) => (json as List).map((e) => Deposit.fromJson(e as Map<String, dynamic>)).toList(),
    query: customerId == null ? null : {'customerId': customerId},
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

final depositSummaryProvider = FutureProvider.autoDispose.family<DepositSummary?, String>((ref, customerId) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<DepositSummary>(
    '/api/customers/$customerId/deposit-summary',
    (json) => DepositSummary.fromJson(json as Map<String, dynamic>),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    _ => null,
  };
});
