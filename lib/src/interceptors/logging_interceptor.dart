import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_commons/flutter_commons.dart';

const _tag = 'DIO';

class LoggingInterceptor extends Interceptor {
  final String name;
  final Logger logger;
  bool _enabled;
  bool logHeaders;
  bool truncateMessages;

  bool get isEnabled => _enabled;

  set isEnabled(bool value) {
    _enabled = value;
    logger.t("$name => ${value ? 'enabled' : 'disabled'}");
  }

  LoggingInterceptor(
    this.logger, {
    required this.name,
    this.logHeaders = true,
    bool isEnabled = true,
    this.truncateMessages = false,
  }) : _enabled = isEnabled;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (isEnabled) {
      logger.logMessage('=> ${options.method} ${options.uri}', tag: _tag, truncateMessage: false);

      if (logHeaders) {
        logger.logMessage('=> HEADERS: ${options.headers}', tag: _tag, truncateMessage: false);
      }

      if (options.data != null) {
        logger.logMessage('=> ${options.data}', tag: _tag, truncateMessage: truncateMessages);
      }
    }

    return handler.next(options.copyWith(extra: {"start-time": DateTime.now().millisecondsSinceEpoch}));
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (isEnabled) {
      verbose(response);
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isEnabled) {
      verbose(err.response, error: err);
    }

    return handler.next(err);
  }

  void verbose<T>(Response<T>? response, {DioException? error}) {
    if (response == null) {
      return;
    }

    var startTime = DateTime.fromMillisecondsSinceEpoch(response.requestOptions.extra['start-time'] as int);
    var endTime = DateTime.now();
    var msec = endTime.difference(startTime).inMilliseconds;
    // logger.logMessage('<=  ${err.requestOptions.uri} ($msec msec)', tag: _tag, truncateMessage: false);

    dynamic contentLength = response.headers['content-length']?.firstOrNull ?? _calculateContentLength(response);
    logger.logMessage(
      '<= ${response.statusCode} ${error == null ? '' : 'ERROR | '}${response.requestOptions.method} ${response.requestOptions.uri} ${response.statusMessage} ($contentLength bytes / $msec msec)',
      tag: _tag,
      truncateMessage: truncateMessages,
    );

    if (response.data != null) {
      if (response.data is Map || response.data is Iterable) {
        logger.logMessage('<= ${jsonEncode(response.data)}', tag: _tag, truncateMessage: truncateMessages);
      } else {
        logger.logMessage('<= ${response.data}', tag: _tag, truncateMessage: truncateMessages);
      }
    }
  }

  int _calculateContentLength(Response response) {
    var len = switch (response.requestOptions.responseType) {
      ResponseType.json => jsonEncode(response.data).length,
      ResponseType.stream => -1,
      ResponseType.plain => (response.data as String).length,
      ResponseType.bytes => (response.data as List).length,
    };
    return len;
  }
}
