import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'notification_settings_model.dart';

final notificationSettingsProvider = FutureProvider.autoDispose<NotificationSettings?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<NotificationSettings>(
    '/api/notification-settings',
    (json) => NotificationSettings.fromJson(json as Map<String, dynamic>),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    _ => null,
  };
});
