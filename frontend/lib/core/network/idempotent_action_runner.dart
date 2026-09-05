import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'api_client.dart';
import 'api_result.dart';

/// Generic version of the per-attempt Idempotency-Key discipline (ARCHITECTURE.md §9/§34):
/// one key per logical action, reused across retries of an unconfirmed outcome, cleared only once
/// the outcome is confirmed (success or a real error response) — never on a network error.
class IdempotentActionRunner {
  final ApiClient _api;
  final Map<String, String> _keysInFlight = {};

  IdempotentActionRunner(this._api);

  Future<ApiResult<T>> run<T>({
    required String actionId,
    required Future<ApiResult<T>> Function(String idempotencyKey) call,
  }) async {
    final key = _keysInFlight.putIfAbsent(actionId, () => _api.newIdempotencyKey());
    final result = await call(key);

    if (result is! ApiNetworkError) {
      _keysInFlight.remove(actionId);
    }

    return result;
  }
}

final idempotentActionRunnerProvider = Provider<IdempotentActionRunner>((ref) {
  return IdempotentActionRunner(ref.watch(apiClientProvider));
});
