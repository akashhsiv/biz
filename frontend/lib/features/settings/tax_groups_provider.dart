import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'tax_group_model.dart';

/// Every active Tax Group for this shop.
final taxGroupsProvider = FutureProvider.autoDispose<List<TaxGroup>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<TaxGroup>>(
    '/api/tax-groups',
    (json) => (json as List).map((e) => TaxGroup.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

/// Creates a new Tax Group. Returns an error message on failure, or null on success.
Future<String?> createTaxGroup(WidgetRef ref, String name, double ratePercent) async {
  final api = ref.read(apiClientProvider);
  final result = await api.post<Map<String, dynamic>>(
    '/api/tax-groups',
    (json) => json as Map<String, dynamic>,
    body: {'name': name, 'ratePercent': ratePercent},
  );

  return switch (result) {
    ApiSuccess() => null,
    ApiFailure(message: final msg) => msg,
    ApiNetworkError(message: final msg) => 'Could not reach the Host: $msg',
  };
}
