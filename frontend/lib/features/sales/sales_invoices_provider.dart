import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'sales_invoice_model.dart';

final salesInvoicesProvider = FutureProvider.autoDispose<List<SalesInvoice>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<SalesInvoice>>(
    '/api/sales-invoices',
    (json) => (json as List).map((e) => SalesInvoice.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
