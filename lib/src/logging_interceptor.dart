import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:siberian_logger/siberian_logger.dart';

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
      var startTime = DateTime.fromMillisecondsSinceEpoch(err.requestOptions.extra['start-time'] as int);
      var endTime = DateTime.now();
      var msec = endTime.difference(startTime).inMilliseconds;
      logger.logMessage('<= ERROR ${err.requestOptions.uri} ($msec msec)', tag: _tag, truncateMessage: false);
      verbose(err.response);
    }

    return handler.next(err);
  }

  void verbose<T>(Response<T>? response) {
    if (response == null) {
      return;
    }

    var startTime = DateTime.fromMillisecondsSinceEpoch(response.requestOptions.extra['start-time'] as int);
    var endTime = DateTime.now();
    var msec = endTime.difference(startTime).inMilliseconds;

    dynamic contentLength = response.headers['content-length']?.firstOrNull ?? _calculateContentLength(response);
    logger.logMessage(
      '<= ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri} \'${response.statusMessage}\' ($contentLength bytes / $msec msec)',
      tag: _tag,
      truncateMessage: truncateMessages,
    );

    if (response.data != null) {
      if (response.data is Map) {
        logger.logMessage('<= ${jsonEncode(response.data)}}', tag: _tag, truncateMessage: truncateMessages);
      } else {
        logger.logMessage('$_tag <= ${response.data}}', tag: _tag, truncateMessage: truncateMessages);
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
