import 'dart:developer' as dev;
import 'dart:io';
import 'package:dio/dio.dart';

/// Exception hierarchy for structured error handling.
sealed class AppException implements Exception {
  final String message;
  final String? details;

  const AppException(this.message, {this.details});

  @override
  String toString() => message;
}

/// No internet or server unreachable.
class NetworkException extends AppException {
  const NetworkException({String? details})
      : super('네트워크 연결을 확인해주세요', details: details);
}

/// Request timed out.
class TimeoutException extends AppException {
  const TimeoutException({String? details})
      : super('서버 응답이 너무 느립니다', details: details);
}

/// Server returned 5xx error.
class ServerException extends AppException {
  final int? statusCode;
  const ServerException({this.statusCode, String? details})
      : super('서버에 문제가 발생했습니다', details: details);
}

/// Server returned 4xx error.
class ClientException extends AppException {
  final int statusCode;
  const ClientException({required this.statusCode, String? details})
      : super('요청을 처리할 수 없습니다', details: details);
}

/// 404 Not Found.
class NotFoundException extends AppException {
  const NotFoundException({String? details})
      : super('요청한 항목을 찾을 수 없습니다', details: details);
}

/// Response parsing failed.
class ParseException extends AppException {
  const ParseException({String? details})
      : super('데이터를 처리하는 중 오류가 발생했습니다', details: details);
}

/// Unknown / fallback.
class UnknownException extends AppException {
  const UnknownException({String? details})
      : super('알 수 없는 오류가 발생했습니다', details: details);
}

class ApiClient {
  late final Dio _dio;

  // Change this to your backend URL
  static final String _baseUrl = Platform.isAndroid
      ? 'http://10.0.2.2:8000/api/v1'
      : 'http://localhost:8000/api/v1';

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Logging interceptor (debug only)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          dev.log('[API] ${options.method} ${options.uri}', name: 'ApiClient');
          handler.next(options);
        },
        onResponse: (response, handler) {
          dev.log('[API] ${response.statusCode} ${response.requestOptions.uri}', name: 'ApiClient');
          handler.next(response);
        },
        onError: (error, handler) {
          dev.log('[API] ERROR ${error.type}: ${error.message}', name: 'ApiClient');
          handler.next(error);
        },
      ),
    );

    // Retry interceptor for transient failures
    _dio.interceptors.add(_RetryInterceptor(_dio));
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _wrapRequest(() => _dio.get(path, queryParameters: queryParameters));
  }

  Future<Response> post(String path, {dynamic data}) {
    return _wrapRequest(() => _dio.post(path, data: data));
  }

  Future<Response> put(String path, {dynamic data}) {
    return _wrapRequest(() => _dio.put(path, data: data));
  }

  Future<Response> delete(String path) {
    return _wrapRequest(() => _dio.delete(path));
  }

  /// Wraps all requests to convert DioException → AppException.
  Future<Response> _wrapRequest(Future<Response> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on SocketException {
      throw const NetworkException();
    } catch (e) {
      throw UnknownException(details: e.toString());
    }
  }

  /// Maps DioException to the appropriate AppException subclass.
  static AppException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(details: e.message);

      case DioExceptionType.connectionError:
        return NetworkException(details: e.message);

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        final body = e.response?.data;
        final detail = body is Map ? body['detail']?.toString() : null;

        if (statusCode == 404) {
          return NotFoundException(details: detail);
        } else if (statusCode >= 500) {
          return ServerException(statusCode: statusCode, details: detail);
        } else {
          return ClientException(statusCode: statusCode, details: detail ?? e.message);
        }

      case DioExceptionType.cancel:
        return const UnknownException(details: 'Request cancelled');

      default:
        return UnknownException(details: e.message);
    }
  }
}

/// Retries failed requests up to [maxRetries] times for transient errors.
class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  static const int maxRetries = 2;

  _RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;
    final shouldRetry = retryCount < maxRetries && _isRetryable(err);

    if (shouldRetry) {
      err.requestOptions.extra['retryCount'] = retryCount + 1;
      dev.log('[API] Retrying (${retryCount + 1}/$maxRetries)...', name: 'ApiClient');

      await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));

      try {
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } on DioException catch (e) {
        handler.next(e);
        return;
      }
    }

    handler.next(err);
  }

  bool _isRetryable(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500);
  }
}
