import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'salary_model.dart';

/// Salary history for one staff member — the backend nests this route under
/// `api/staff/{staffId}/salary`, so it's fetched per-staff rather than globally (there is no
/// "all staff, all months" list endpoint on the backend to back a flat top-level screen).
final staffSalaryListProvider =
    FutureProvider.autoDispose.family<List<SalaryPayment>, String>((ref, staffId) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<SalaryPayment>>(
    '/api/staff/$staffId/salary',
    (json) => (json as List).map((e) => SalaryPayment.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
