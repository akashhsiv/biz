import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../logging/file_logger.dart';
import '../storage/app_storage.dart';
import 'api_result.dart';

const _uuid = Uuid();

/// Thin Dio wrapper: attaches the bearer token to every request, normalizes every response into
/// an [ApiResult] so callers can never accidentally treat a network drop as success or failure.
class ApiClient {
  final AppStorage storage;
  late Dio _dio;
  String? _baseUrl;

  ApiClient(this.storage) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  void setBaseUrl(String url) {
    final normalized = url.startsWith('http') ? url : 'http://$url';
    _baseUrl = normalized.endsWith('/') ? normalized.substring(0, normalized.length - 1) : normalized;
    _dio.options.baseUrl = _baseUrl!;
  }

  String? get baseUrl => _baseUrl;

  /// Generates a fresh Idempotency-Key for a new logical action. Callers must hold onto this and
  /// reuse it for every retry of the *same* attempt (ARCHITECTURE.md §9/§34) — only mint a new one
  /// when the user changes the request (edits the form) rather than just retrying.
  String newIdempotencyKey() => _uuid.v4();

  Future<ApiResult<T>> get<T>(String path, T Function(dynamic json) parse, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query), parse);

  /// For binary responses (PDFs) — bypasses JSON decoding entirely. A longer receive timeout than
  /// normal API calls: generating a PDF launches/uses headless Chromium server-side, which can
  /// take noticeably longer than a typical JSON response, especially on a first render after the
  /// Host service just started.
  Future<ApiResult<List<int>>> getBytes(String path, {Duration receiveTimeout = const Duration(seconds: 60)}) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes, receiveTimeout: receiveTimeout),
      );
      return ApiSuccess<List<int>>(response.data ?? const []);
    } on DioException catch (e) {
      return _mapError<List<int>>(e);
    } catch (e) {
      return ApiNetworkError<List<int>>(e.toString());
    }
  }

  Future<ApiResult<T>> post<T>(String path, T Function(dynamic json) parse,
          {Object? body, String? idempotencyKey, Duration? receiveTimeout, Map<String, dynamic>? query}) =>
      _send(
        () => _dio.post(
          path,
          data: body,
          queryParameters: query,
          options: _withIdempotency(idempotencyKey)?.copyWith(receiveTimeout: receiveTimeout) ?? Options(receiveTimeout: receiveTimeout),
        ),
        parse,
      );

  Future<ApiResult<T>> put<T>(String path, T Function(dynamic json) parse, {Object? body}) =>
      _send(() => _dio.put(path, data: body), parse);

  Future<ApiResult<T>> delete<T>(String path, T Function(dynamic json) parse) =>
      _send(() => _dio.delete(path), parse);

  Options? _withIdempotency(String? key) =>
      key == null ? null : Options(headers: {'Idempotency-Key': key});

  Future<ApiResult<T>> _send<T>(Future<Response> Function() call, T Function(dynamic json) parse) async {
    try {
      final response = await call();
      try {
        return ApiSuccess(parse(response.data));
      } catch (e, st) {
        // The request itself succeeded, but decoding/parsing the response into our model failed —
        // log the raw response alongside the parse error so a shape mismatch is diagnosable.
        FileLogger.log('Response parse failed for ${response.requestOptions.method} ${response.requestOptions.path}: $e\nRaw response: ${response.data}', stackTrace: st);
        return ApiNetworkError<T>('Could not understand the Host\'s response: $e');
      }
    } on DioException catch (e) {
      return _mapError<T>(e);
    } catch (e, st) {
      FileLogger.log('Unexpected error during API call: $e', stackTrace: st);
      return ApiNetworkError<T>(e.toString());
    }
  }

  ApiResult<T> _mapError<T>(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        // A "connection refused" (nothing listening on that port) is a different, more actionable
        // problem than a real network/timeout issue — say so instead of a generic message.
        final underlying = e.error?.toString() ?? '';
        if (underlying.toLowerCase().contains('refused')) {
          return ApiNetworkError<T>('No Host service is listening at that address. Is the Host installed and running?');
        }
        return ApiNetworkError<T>('Could not reach the Host. Check the address and your network connection.');
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiNetworkError<T>('Timed out reaching the Host. It may be starting up, or on a different network.');
      case DioExceptionType.cancel:
        return ApiNetworkError<T>('Request was cancelled.');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final detail = _extractDetail(e.response?.data);
        // Every failed API call gets logged with its real status/body here — the message the user
        // sees (often just "Something went wrong.") is a fallback for missing detail/title fields,
        // but the actual server response is always worth having on hand to diagnose it.
        FileLogger.log('API ${e.requestOptions.method} ${e.requestOptions.path} -> HTTP $status\nBody: ${e.response?.data}');
        return ApiFailure<T>(status, detail);
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      default:
        FileLogger.log('API ${e.requestOptions.method} ${e.requestOptions.path} -> unexpected DioException: ${e.type} - ${e.message}');
        return ApiNetworkError<T>('Unexpected connection error: ${e.message}');
    }
  }

  String _extractDetail(dynamic data) {
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    if (data is Map && data['title'] is String) return data['title'] as String;
    return 'Something went wrong.';
  }
}
