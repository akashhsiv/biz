import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'commission_model.dart';

/// Filter for the customer-rates list — a record so the family provider gets structural equality
/// (matches Dart 3 records semantics) without hand-rolling a class with ==/hashCode.
typedef CustomerRateFilter = ({String? customerId, bool includeInactive});

final customerProductRatesProvider =
    FutureProvider.autoDispose.family<List<CustomerProductRate>, CustomerRateFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<CustomerProductRate>>(
    '/api/commission/customer-rates',
    (json) => (json as List).map((e) => CustomerProductRate.fromJson(e as Map<String, dynamic>)).toList(),
    query: {
      if (filter.customerId != null) 'customerId': filter.customerId,
      'includeInactive': filter.includeInactive,
    },
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

/// Filter for the commission-entries list.
typedef CommissionEntryFilter = ({
  String? customerId,
  CommissionEntryStatus? status,
  DateTime? fromDate,
  DateTime? toDate,
});

const noCommissionEntryFilter = (customerId: null, status: null, fromDate: null, toDate: null);

final commissionEntriesProvider =
    FutureProvider.autoDispose.family<List<CommissionEntry>, CommissionEntryFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<CommissionEntry>>(
    '/api/commission/entries',
    (json) => (json as List).map((e) => CommissionEntry.fromJson(e as Map<String, dynamic>)).toList(),
    query: {
      if (filter.customerId != null) 'customerId': filter.customerId,
      if (filter.status != null) 'status': filter.status!.index,
      if (filter.fromDate != null) 'fromDate': filter.fromDate!.toIso8601String(),
      if (filter.toDate != null) 'toDate': filter.toDate!.toIso8601String(),
    },
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
