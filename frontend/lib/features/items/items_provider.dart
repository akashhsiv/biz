import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_result.dart';
import '../../core/providers.dart';
import 'item_model.dart';

final itemsProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.get<List<Item>>(
    '/api/items',
    (json) => (json as List).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList(),
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});

/// Items scoped to a Category and/or a Brand — used by the Purchase/Sales create flows, where the
/// line-item picker must only offer items the target document is allowed to contain.
class ItemsFilter {
  final String? categoryId;
  final String? brandId;

  const ItemsFilter({this.categoryId, this.brandId});

  @override
  bool operator ==(Object other) => other is ItemsFilter && other.categoryId == categoryId && other.brandId == brandId;

  @override
  int get hashCode => Object.hash(categoryId, brandId);
}

final itemsFilteredProvider = FutureProvider.autoDispose.family<List<Item>, ItemsFilter>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final query = <String, dynamic>{
    if (filter.categoryId != null) 'categoryId': filter.categoryId,
    if (filter.brandId != null) 'brandId': filter.brandId,
  };
  final result = await api.get<List<Item>>(
    '/api/items',
    (json) => (json as List).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList(),
    query: query.isEmpty ? null : query,
  );

  return switch (result) {
    ApiSuccess(data: final data) => data,
    ApiFailure(message: final msg) => throw Exception(msg),
    ApiNetworkError(message: final msg) => throw Exception(msg),
  };
});
