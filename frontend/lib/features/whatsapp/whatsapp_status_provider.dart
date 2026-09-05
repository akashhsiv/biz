import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';

/// Shared with the WhatsApp screen and the app-wide top bar — one provider, one poll, instead of
/// each place hitting /api/whatsapp/status on its own.
final whatsappStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<Map<String, dynamic>>('/api/whatsapp/status', (json) => json as Map<String, dynamic>);
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});

/// Every logged-in user can see this one (unlike [whatsappStatusProvider], which needs
/// whatsapp.manage) - just the connected/reachable booleans, via /api/whatsapp/connection-status.
/// Self-refreshing (unlike [whatsappStatusProvider], which relies on the WhatsApp screen to
/// invalidate it) - this drives the always-visible top bar chip, which previously only fetched once
/// and could go stale for as long as nothing else happened to invalidate it (e.g. showing "Not
/// Paired" long after actually pairing on the WhatsApp screen, which polls its own separate provider).
final whatsappConnectionStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final timer = Timer.periodic(const Duration(seconds: 10), (_) => ref.invalidateSelf());
  ref.onDispose(timer.cancel);

  final api = ref.watch(apiClientProvider);
  final result = await api.get<Map<String, dynamic>>('/api/whatsapp/connection-status', (json) => json as Map<String, dynamic>);
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});
