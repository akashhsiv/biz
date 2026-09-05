import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'quotation_model.dart';

final quotationsProvider = FutureProvider.autoDispose<List<Quotation>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Quotation>>(
    '/api/quotations',
    (json) => (json as List).map((e) => Quotation.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

/// Wraps the convert action's Idempotency-Key discipline: one key per logical tap, reused across
/// retries of an unconfirmed ("unknown") outcome, replaced only when the user starts a fresh attempt.
class QuotationConvertController {
  final ApiClient _api;
  final Map<String, String> _keysInFlight = {};

  QuotationConvertController(this._api);

  Future<ApiResult<ConvertResult>> convert(String quotationId) async {
    final key = _keysInFlight.putIfAbsent(quotationId, () => _api.newIdempotencyKey());

    final result = await _api.post<ConvertResult>(
      '/api/quotations/$quotationId/convert',
      (json) => ConvertResult.fromJson(json as Map<String, dynamic>),
      body: const {},
      idempotencyKey: key,
    );

    // Only clear the key once we have a confirmed outcome — a network error keeps it so a Retry
    // reuses the same key and stays safe against duplicate execution.
    if (result is! ApiNetworkError) {
      _keysInFlight.remove(quotationId);
    }

    return result;
  }
}

final quotationConvertControllerProvider = Provider<QuotationConvertController>((ref) {
  return QuotationConvertController(ref.watch(apiClientProvider));
});
