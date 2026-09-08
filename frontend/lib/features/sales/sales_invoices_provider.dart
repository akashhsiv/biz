import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import '../reports/document_payment_status.dart';
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

/// The full filter set the backend's `GET /api/sales-invoices` accepts (see
/// SalesInvoicesController.List) — used by the per-category Sales List tab.
class SalesListFilter {
  final String categoryId;
  final String? customerId;
  final String? brandId;
  final SalesInvoiceStatus? status;
  final DocumentPaymentStatus? paymentStatus;
  final DateTime? from;
  final DateTime? to;
  final String? search;
  final bool overdueOnly;

  const SalesListFilter({
    required this.categoryId,
    this.customerId,
    this.brandId,
    this.status,
    this.paymentStatus,
    this.from,
    this.to,
    this.search,
    this.overdueOnly = false,
  });

  @override
  bool operator ==(Object other) =>
      other is SalesListFilter &&
      other.categoryId == categoryId &&
      other.customerId == customerId &&
      other.brandId == brandId &&
      other.status == status &&
      other.paymentStatus == paymentStatus &&
      other.from == from &&
      other.to == to &&
      other.search == search &&
      other.overdueOnly == overdueOnly;

  @override
  int get hashCode => Object.hash(categoryId, customerId, brandId, status, paymentStatus, from, to, search, overdueOnly);
}

final salesInvoicesFilteredProvider = FutureProvider.autoDispose.family<List<SalesInvoice>, SalesListFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<SalesInvoice>>(
    '/api/sales-invoices',
    (json) => (json as List).map((e) => SalesInvoice.fromJson(e as Map<String, dynamic>)).toList(),
    query: {
      'categoryId': filter.categoryId,
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.brandId != null) 'brandId': filter.brandId,
      if (filter.status != null) 'status': filter.status!.index,
      if (filter.paymentStatus != null) 'paymentStatus': filter.paymentStatus!.index,
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
