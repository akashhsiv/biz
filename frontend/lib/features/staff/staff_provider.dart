import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'staff_model.dart';

final staffListProvider = FutureProvider.autoDispose<List<Staff>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Staff>>(
    '/api/staff',
    (json) => (json as List).map((e) => Staff.fromJson(e as Map<String, dynamic>)).toList(),
    query: {'includeInactive': true},
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
