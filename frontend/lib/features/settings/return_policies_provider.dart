import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'return_policy_model.dart';

/// Every active Return Policy for this shop.
final returnPoliciesProvider = FutureProvider.autoDispose<List<ReturnPolicy>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<ReturnPolicy>>(
    '/api/return-policies',
    (json) => (json as List).map((e) => ReturnPolicy.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

/// Creates a new Return Policy. Returns an error message on failure, or null on success.
Future<String?> createReturnPolicy(
  WidgetRef ref, {
  required String name,
  String? categoryId,
  required int returnWindowDays,
  required double restockingFeePercent,
}) async {
  final api = ref.read(apiClientProvider);
  final result = await api.post<Map<String, dynamic>>(
    '/api/return-policies',
    (json) => json as Map<String, dynamic>,
    body: {
      'name': name,
      'categoryId': categoryId,
      'returnWindowDays': returnWindowDays,
      'restockingFeePercent': restockingFeePercent,
    },
  );

  return switch (result) {
    ApiSuccess() => null,
    ApiFailure(message: final msg) => msg,
    ApiNetworkError(message: final msg) => 'Could not reach the Host: $msg',
  };
}

/// Deactivates a Return Policy. Returns an error message on failure, or null on success.
Future<String?> deactivateReturnPolicy(WidgetRef ref, String id) async {
  final api = ref.read(apiClientProvider);
  final result = await api.post<void>('/api/return-policies/$id/deactivate', (_) {});

  return switch (result) {
    ApiSuccess() => null,
    ApiFailure(message: final msg) => msg,
    ApiNetworkError(message: final msg) => 'Could not reach the Host: $msg',
  };
}
