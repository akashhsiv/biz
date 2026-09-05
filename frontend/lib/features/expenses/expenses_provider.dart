import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'expense_model.dart';

final expensesProvider = FutureProvider.autoDispose<List<Expense>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Expense>>(
    '/api/expenses',
    (json) => (json as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
