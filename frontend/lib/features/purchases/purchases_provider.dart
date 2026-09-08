import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../reports/document_payment_status.dart';
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

/// The full filter set the backend's `GET /api/purchase-orders` accepts (see
/// PurchaseOrdersController.List) — used by the per-category Purchase List tab.
class PurchaseListFilter {
  final String categoryId;
  final String? supplierId;
  final String? brandId;
  final PurchaseOrderStatus? status;
  final DocumentPaymentStatus? balancePaymentStatus;
  final DateTime? from;
  final DateTime? to;
  final String? search;
  final bool overdueOnly;

  const PurchaseListFilter({
    required this.categoryId,
    this.supplierId,
    this.brandId,
    this.status,
    this.balancePaymentStatus,
    this.from,
    this.to,
    this.search,
    this.overdueOnly = false,
  });

  @override
  bool operator ==(Object other) =>
      other is PurchaseListFilter &&
      other.categoryId == categoryId &&
      other.supplierId == supplierId &&
      other.brandId == brandId &&
      other.status == status &&
      other.balancePaymentStatus == balancePaymentStatus &&
      other.from == from &&
      other.to == to &&
      other.search == search &&
      other.overdueOnly == overdueOnly;

  @override
  int get hashCode => Object.hash(categoryId, supplierId, brandId, status, balancePaymentStatus, from, to, search, overdueOnly);
}

final purchaseOrdersFilteredProvider = FutureProvider.autoDispose.family<List<PurchaseOrder>, PurchaseListFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<PurchaseOrder>>(
    '/api/purchase-orders',
    (json) => (json as List).map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>)).toList(),
    query: {
      'categoryId': filter.categoryId,
      if (filter.supplierId != null) 'supplierId': filter.supplierId,
      if (filter.brandId != null) 'brandId': filter.brandId,
      if (filter.status != null) 'status': filter.status!.index,
      if (filter.balancePaymentStatus != null) 'balancePaymentStatus': filter.balancePaymentStatus!.index,
      if (filter.from != null) 'from': filter.from!.toIso8601String(),
      if (filter.to != null) 'to': filter.to!.toIso8601String(),
      if (filter.search != null && filter.search!.isNotEmpty) 'search': filter.search,
      if (filter.overdueOnly) 'overdueOnly': true,
    },
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
