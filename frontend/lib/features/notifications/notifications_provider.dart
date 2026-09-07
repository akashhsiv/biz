import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'notification_model.dart';

/// Filter for [notificationsProvider] - a value type with proper ==/hashCode so the
/// autoDispose.family provider caches correctly per distinct filter, same pattern as
/// PaymentStatusReportFilter/CustomerReportFilter in reports_provider.dart.
class NotificationsFilter {
  final int page;
  final int pageSize;
  final bool unreadOnly;

  const NotificationsFilter({this.page = 1, this.pageSize = 50, this.unreadOnly = false});

  @override
  bool operator ==(Object other) =>
      other is NotificationsFilter && other.page == page && other.pageSize == pageSize && other.unreadOnly == unreadOnly;

  @override
  int get hashCode => Object.hash(page, pageSize, unreadOnly);
}

final notificationsProvider = FutureProvider.autoDispose.family<List<NotificationItem>?, NotificationsFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<dynamic>>(
    '/api/notifications',
    (json) => json as List<dynamic>,
    query: {'page': filter.page, 'pageSize': filter.pageSize, 'unreadOnly': filter.unreadOnly},
  );
  return switch (result) {
    ApiSuccess(data: final data) => data.map((e) => NotificationItem.fromJson(e as Map<String, dynamic>)).toList(),
    _ => null,
  };
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<Map<String, dynamic>>('/api/notifications/unread-count', (json) => json as Map<String, dynamic>);
  return switch (result) {
    ApiSuccess(data: final data) => (data['count'] as num?)?.toInt() ?? 0,
    _ => 0,
  };
});

class NotificationsActions {
  final Ref ref;
  NotificationsActions(this.ref);

  Future<bool> markRead(String id) async {
    final api = ref.read(apiClientProvider);
    final result = await api.post<void>('/api/notifications/$id/read', (_) {});
    final ok = result is ApiSuccess<void>;
    if (ok) _invalidate();
    return ok;
  }

  Future<bool> markAllRead() async {
    final api = ref.read(apiClientProvider);
    final result = await api.post<void>('/api/notifications/read-all', (_) {});
    final ok = result is ApiSuccess<void>;
    if (ok) _invalidate();
    return ok;
  }

  void _invalidate() {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }
}

final notificationsActionsProvider = Provider((ref) => NotificationsActions(ref));
