import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'customer_report_model.dart';

final salesReportProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<Map<String, dynamic>>('/api/reports/sales', (json) => json as Map<String, dynamic>);
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});

final purchaseReportProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<Map<String, dynamic>>('/api/reports/purchase', (json) => json as Map<String, dynamic>);
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});

final lowStockReportProvider = FutureProvider.autoDispose<List<dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<dynamic>>('/api/reports/stock/low', (json) => json as List<dynamic>);
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});

final financeReportProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<Map<String, dynamic>>('/api/reports/finance', (json) => json as Map<String, dynamic>);
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});

final outstandingReportProvider = FutureProvider.autoDispose<List<dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<dynamic>>('/api/reports/finance/outstanding', (json) => json as List<dynamic>);
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});

final auditReportProvider = FutureProvider.autoDispose<List<dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<dynamic>>('/api/reports/audit', (json) => json as List<dynamic>);
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});

final customerReportProvider = FutureProvider.autoDispose.family<List<CustomerReportRow>?, CustomerReportFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final query = <String, dynamic>{
    if (filter.from != null) 'from': filter.from!.toIso8601String(),
    if (filter.to != null) 'to': filter.to!.toIso8601String(),
    if (filter.customerId != null) 'customerId': filter.customerId,
    'page': 1,
    'pageSize': 50,
  };
  final result = await api.get<List<dynamic>>('/api/reports/customer', (json) => json as List<dynamic>, query: query);
  return switch (result) {
    ApiSuccess(data: final data) => data.map((e) => CustomerReportRow.fromJson(e as Map<String, dynamic>)).toList(),
    _ => null,
  };
});
