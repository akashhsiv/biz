import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'purchase_order_model.dart';
import 'supplier_model.dart';

final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Supplier>>(
    '/api/suppliers',
    (json) => (json as List).map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

final purchaseOrdersProvider = FutureProvider.autoDispose<List<PurchaseOrder>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<PurchaseOrder>>(
    '/api/purchase-orders',
    (json) => (json as List).map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
