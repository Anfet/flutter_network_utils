import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_logger/siberian_logger.dart';

import 'network_exceptions.dart';

enum NetworkCallMethod { get, post, patch, delete, put }

class NetworkCallExecutor with Logging {
  Dio _dio;

  set dio(Dio value) => _dio = value;

  final AsyncTypedResultCallback<Options, Options>? onPreRequest;
  final Future<void> Function(Options? options, int elapsedMilliseconds)? onPostRequest;
  final TypedResultCallback<Object?, Response?>? networkErrorTransformer;

  NetworkCallExecutor(
    this._dio, {
    this.onPreRequest,
    this.onPostRequest,
    this.networkErrorTransformer,
  });

  Future<T> get<T>(String url, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) =>
      request(url, method: NetworkCallMethod.get, data: data, queryParameters: queryParameters, options: options);

  Future<T> post<T>(String url, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) =>
      request(url, method: NetworkCallMethod.post, data: data, queryParameters: queryParameters, options: options);

  Future<T> put<T>(String url, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) =>
      request(url, method: NetworkCallMethod.put, data: data, queryParameters: queryParameters, options: options);

  Future<T> patch<T>(String url, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) =>
      request(url, method: NetworkCallMethod.patch, data: data, queryParameters: queryParameters, options: options);

  Future<T> delete<T>(String url, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) =>
      request(url, method: NetworkCallMethod.delete, data: data, queryParameters: queryParameters, options: options);

  Future<T> custom<T>(FutureOr<T> Function(Dio dio) block) async {
    try {
      T result = await block(_dio);
      return result;
    } catch (ex) {
      var error = _parseNetworkException(ex);
      warn(error, stack: StackTrace.current, error: error);
      throw error;
    }
  }

  Future<T> request<T>(String url, {required NetworkCallMethod method, Object? data, Map<String, dynamic>? queryParameters, Options? options}) async {
    options ??= Options();
    options.headers ??= {};
    options.extra ??= {};
    options.extra?['url'] = url;
    options.extra?['start-time'] = DateTime.now().millisecondsSinceEpoch;
    try {
      if (onPreRequest != null) {
        options = await onPreRequest?.call(options);
      }
      final response = await switch (method) {
        NetworkCallMethod.get => _dio.get(url, data: data, queryParameters: queryParameters, options: options),
        NetworkCallMethod.post => _dio.post(url, data: data, queryParameters: queryParameters, options: options),
        NetworkCallMethod.patch => _dio.patch(url, data: data, queryParameters: queryParameters, options: options),
        NetworkCallMethod.delete => _dio.delete(url, data: data, queryParameters: queryParameters, options: options),
        NetworkCallMethod.put => _dio.put(url, data: data, queryParameters: queryParameters, options: options),
      };

      T result = response.data;
      return result;
    } catch (ex, stack) {
      // recordException(ex, ex, stack);
      var error = _parseNetworkException(ex);
      throw error;
    } finally {
      var elapsedMilliseconds = DateTime.now().millisecondsSinceEpoch - require(options?.extra?['start-time']) as int;
      await onPostRequest?.call(options, elapsedMilliseconds);
    }
  }

  Object _parseNetworkException(Object exception) {
    if (exception is SocketException) {
      return networkErrorTransformer?.call(null) ?? NoNetworkException(exception.message);
    }

    if (exception is DioException) {
      var ex = exception;
      switch (ex.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          return networkErrorTransformer?.call(null) ?? NoNetworkException(ex.message ?? '');
        case DioExceptionType.cancel:
          return CancelledException();
        default:
          var defaultException = NetworkException('${ex.response?.statusCode} ${ex.type.name}');
          if (ex.response?.statusCode != null) {
            defaultException = ServerException(defaultException.message, status: require(ex.response?.statusCode), data: ex.response?.data);
          }
          var error = ex.error ?? networkErrorTransformer?.call(ex.response) ?? defaultException;
          return error;
      }
    }

    return exception;
  }
}
