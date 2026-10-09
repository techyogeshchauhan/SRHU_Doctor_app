import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// REST API Client connecting to the MongoDB Atlas Express backend.
///
/// Configured via --dart-define:
///   --dart-define=API_BASE_URL=https://api.yourdomain.com
///   --dart-define=API_KEY=your-client-api-key
class ApiClient {
  ApiClient({
    String? baseUrl,
    String? apiKey,
    Dio? dio,
  })  : _baseUrl = baseUrl ?? _envBaseUrl,
        _apiKey = apiKey ?? _envApiKey {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: _baseUrl.isEmpty ? '' : _normalizeBaseUrl(_baseUrl),
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              if (_apiKey.isNotEmpty) 'x-api-key': _apiKey,
            },
          ),
        );

    // PHI-safe logging interceptor: NEVER log payload or response bodies
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode) {
            debugPrint('[ApiClient] → ${options.method} ${options.path}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '[ApiClient] ← ${response.statusCode} ${response.requestOptions.path}',
            );
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          if (kDebugMode) {
            debugPrint(
              '[ApiClient] ✖ Error ${e.response?.statusCode ?? 'NETWORK'}: ${e.message}',
            );
          }
          return handler.next(e);
        },
      ),
    );
  }

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envApiKey = String.fromEnvironment('API_KEY');

  final String _baseUrl;
  final String _apiKey;
  late final Dio _dio;

  static String _normalizeBaseUrl(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Whether the client is configured with base URL and API key.
  bool get isConfigured => _baseUrl.isNotEmpty && _apiKey.isNotEmpty;

  /// Underlying Dio instance.
  Dio get dio => _dio;

  /// Executes an operation with exponential backoff for transient errors.
  Future<Response<T>> _withRetry<T>(
    Future<Response<T>> Function() request, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        attempt++;
        final isNetwork = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError ||
            (e.error is SocketException);

        final statusCode = e.response?.statusCode ?? 0;
        final isServerError = statusCode >= 500 && statusCode < 600;

        if (attempt >= maxRetries || (!isNetwork && !isServerError)) {
          rethrow;
        }

        // Exponential backoff: 300ms, 600ms, 1200ms
        final delayMs = (300 * pow(2, attempt - 1)).toInt();
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  /// POST /sessions
  Future<Response<dynamic>> createSession(Map<String, dynamic> data) {
    return _withRetry(() => _dio.post('/sessions', data: data));
  }

  /// PATCH /sessions/:id
  Future<Response<dynamic>> patchSession(String id, Map<String, dynamic> data) {
    return _withRetry(() => _dio.patch('/sessions/$id', data: data));
  }

  // ---------------------------------------------------------------------------
  // Screenings
  // ---------------------------------------------------------------------------

  /// PUT /screenings/:id
  Future<Response<dynamic>> putScreening(String id, Map<String, dynamic> data) {
    return _withRetry(() => _dio.put('/screenings/$id', data: data));
  }

  /// PUT /screenings/:id/responses/:questionId
  Future<Response<dynamic>> putResponse({
    required String screeningId,
    required String questionId,
    required Map<String, dynamic> data,
  }) {
    return _withRetry(
      () => _dio.put('/screenings/$screeningId/responses/$questionId', data: data),
    );
  }

  /// POST /screenings/:id/findings
  Future<Response<dynamic>> postFindings(
    String screeningId,
    List<Map<String, dynamic>> findings,
  ) {
    return _withRetry(
      () => _dio.post('/screenings/$screeningId/findings', data: {'findings': findings}),
    );
  }

  /// PUT /screenings/:id/findings (replaces all findings of the screening)
  Future<Response<dynamic>> replaceFindings(
    String screeningId,
    List<Map<String, dynamic>> findings,
  ) {
    return _withRetry(
      () => _dio.put('/screenings/$screeningId/findings', data: {'findings': findings}),
    );
  }

  /// POST /screenings/:id/mcq-attempts
  Future<Response<dynamic>> postMcqAttempt(
    String screeningId,
    Map<String, dynamic> data,
  ) {
    return _withRetry(
      () => _dio.post('/screenings/$screeningId/mcq-attempts', data: data),
    );
  }

  /// PATCH /screenings/:id/status
  Future<Response<dynamic>> patchScreeningStatus(
    String screeningId,
    String status, {
    String? completedAt,
  }) {
    final payload = <String, dynamic>{
      'status': status,
      if (completedAt != null) 'completedAt': completedAt,
    };
    return _withRetry(
      () => _dio.patch('/screenings/$screeningId/status', data: payload),
    );
  }

  // ---------------------------------------------------------------------------
  // Chat Logs
  // ---------------------------------------------------------------------------

  /// POST /chat-logs
  Future<Response<dynamic>> postChatLog(Map<String, dynamic> data) {
    return _withRetry(() => _dio.post('/chat-logs', data: data));
  }
}
