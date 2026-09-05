import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'finance_model.dart';

final shopBalanceProvider = FutureProvider.autoDispose<double?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<double>(
    '/api/finance/shop-balance',
    (json) => ((json as Map<String, dynamic>)['balance'] as num).toDouble(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    _ => null,
  };
});

final financialTransactionsProvider = FutureProvider.autoDispose<List<FinancialTransactionEntry>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<FinancialTransactionEntry>>(
    '/api/finance/transactions',
    (json) => (json as List).map((e) => FinancialTransactionEntry.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
