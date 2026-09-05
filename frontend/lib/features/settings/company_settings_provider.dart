import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'company_settings_model.dart';

final companySettingsProvider = FutureProvider.autoDispose<CompanySettings?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<CompanySettings>(
    '/api/company-settings',
    (json) => CompanySettings.fromJson(json as Map<String, dynamic>),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    _ => null,
  };
});

/// The logo endpoint requires the bearer token, so it can't be used directly with Image.network —
/// fetch bytes through the authenticated ApiClient instead and render with Image.memory.
final companyLogoBytesProvider = FutureProvider.autoDispose<List<int>?>((ref) async {
  final settings = await ref.watch(companySettingsProvider.future);
  if (settings?.hasLogo != true) return null;

  final api = ref.watch(apiClientProvider);
  final result = await api.getBytes('/api/company-settings/logo');
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});

/// Same pattern as [companyLogoBytesProvider] — the signature endpoint also needs the bearer token.
final companySignatureBytesProvider = FutureProvider.autoDispose<List<int>?>((ref) async {
  final settings = await ref.watch(companySettingsProvider.future);
  if (settings?.hasSignature != true) return null;

  final api = ref.watch(apiClientProvider);
  final result = await api.getBytes('/api/company-settings/signature');
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});

final backupStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<Map<String, dynamic>>('/api/backup/status', (json) => json as Map<String, dynamic>);
  return switch (result) { ApiSuccess(data: final data) => data, _ => null };
});
