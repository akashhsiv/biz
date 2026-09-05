import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'host_status_model.dart';

final hostStatusProvider = FutureProvider.autoDispose<HostStatus?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<Map<String, dynamic>>('/api/host/status', (json) => json as Map<String, dynamic>);

  switch (result) {
    case ApiSuccess(data: final data):
      try {
        return HostStatus.fromJson(data);
      } catch (e, st) {
        debugPrint('[hostStatusProvider] JSON parse failed: $e\nRaw data: $data\n$st');
        return null;
      }
    case ApiFailure(statusCode: final code, message: final msg):
      debugPrint('[hostStatusProvider] ApiFailure: HTTP $code - $msg');
      return null;
    case ApiNetworkError(message: final msg):
      debugPrint('[hostStatusProvider] ApiNetworkError: $msg');
      return null;
  }
});
