import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';

class UserDirectoryEntry {
  final String id;
  final String fullName;

  UserDirectoryEntry({required this.id, required this.fullName});

  factory UserDirectoryEntry.fromJson(Map<String, dynamic> json) =>
      UserDirectoryEntry(id: json['id'] as String, fullName: json['fullName'] as String);
}

/// Id + full name only, callable by any authenticated user - unlike usersProvider (gated by
/// UsersManage, which most staff roles don't have), this is what list screens use to resolve
/// "Created By" without needing the full user-management permission.
final userDirectoryProvider = FutureProvider.autoDispose<List<UserDirectoryEntry>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<UserDirectoryEntry>>(
    '/api/users/directory',
    (json) => (json as List).map((e) => UserDirectoryEntry.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
