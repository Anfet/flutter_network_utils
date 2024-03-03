import 'dart:io';

import 'package:dio/dio.dart';
import 'package:siberian_core/siberian_core.dart';

import 'network_exceptions.dart';

enum NetworkCallMethod { get, post, patch, delete, put }

class NetworkCallExecutor with Logging {
  final Dio dio;

  final TypedResult<Object> onNoNetwork;
  final AsyncTypedResultCallback<Options, Options>? onPreRequest;
  final Future<void> Function(Options? options, int elapsedMilliseconds)? onPostRequest;
  final TypedResultCallback<Object?, Response?>? onNetworkError;

  NetworkCallExecutor({
    required this.dio,
    required this.onNoNetwork,
    this.onPreRequest,
    this.onPostRequest,
    this.onNetworkError,
  });

  Future<T> get<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      request(
        url,
        method: NetworkCallMethod.get,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

  Future<T> post<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      request(
        url,
        method: NetworkCallMethod.post,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

  Future<T> put<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      request(
        url,
        method: NetworkCallMethod.put,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

  Future<T> patch<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      request(
        url,
        method: NetworkCallMethod.patch,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

  Future<T> delete<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      request(
        url,
        method: NetworkCallMethod.delete,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

  Future<T> request<T>(
    String url, {
    required NetworkCallMethod method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    T? result;
    Object? error;
    options ??= Options();
    options.headers ??= {};
    options.extra?['url'] = url;
    final stopwatch = Stopwatch();
    try {
      if (onPreRequest != null) {
        options = await onPreRequest?.call(options);
      }

      stopwatch.start();
      final response = await switch (method) {
        NetworkCallMethod.get => dio.get(url, data: data, queryParameters: queryParameters, options: options),
        NetworkCallMethod.post => dio.post(url, data: data, queryParameters: queryParameters, options: options),
        NetworkCallMethod.patch => dio.patch(url, data: data, queryParameters: queryParameters, options: options),
        NetworkCallMethod.delete => dio.delete(url, data: data, queryParameters: queryParameters, options: options),
        NetworkCallMethod.put => dio.put(url, data: data, queryParameters: queryParameters, options: options),
      };

      result = response.data;
    } catch (ex) {
      error = parseNetworkException(ex);
    } finally {
      await onPostRequest?.call(options, stopwatch.elapsedMilliseconds);
      stopwatch.stop();
    }

    if (error != null) {
      warn(error, stackTrace: StackTrace.current, error: error);
      throw error;
    }

    if (result != null) {
      return result;
    }

    throw FlowException('no error, no result');
  }

  Object parseNetworkException(Object exception) {
    if (exception is SocketException) {
      return onNoNetwork();
    }

    if (exception is DioException) {
      var ex = exception;
      switch (ex.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          return onNoNetwork();
        case DioExceptionType.cancel:
          return CancelledException();
        default:
          var error = ex.error ?? onNetworkError?.call(ex.response) ?? NetworkException(ex.message ?? ex.toString());
          return error;
      }
    }

    return exception;
  }
}
