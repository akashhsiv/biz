import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'proforma_model.dart';

final proformasProvider = FutureProvider.autoDispose<List<Proforma>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Proforma>>(
    '/api/proformas',
    (json) => (json as List).map((e) => Proforma.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

final proformasByCustomerProvider = FutureProvider.autoDispose.family<List<Proforma>, String>((ref, customerId) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Proforma>>(
    '/api/proformas',
    (json) => (json as List).map((e) => Proforma.fromJson(e as Map<String, dynamic>)).toList(),
    query: {'customerId': customerId},
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
