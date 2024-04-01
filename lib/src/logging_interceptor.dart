import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:siberian_core/siberian_core.dart' as siberian_core;

const _tag = 'DIO';

class LoggingInterceptor extends Interceptor {
  final String name;
  final Logger logger;
  bool _enabled;
  bool logHeaders;

  bool get isEnabled => _enabled;

  set isEnabled(bool value) {
    _enabled = value;
    siberian_core.logger.t("$name => ${value ? 'enabled' : 'disabled'}");
  }

  LoggingInterceptor(this.logger, {
    required this.name,
    this.logHeaders = true,
    bool isEnabled = true,
  }) : _enabled = isEnabled;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (isEnabled) {
      logger.t('$_tag => ${options.method} ${options.uri}');

      if (logHeaders) {
        logger.t('$_tag => HEADERS: ${options.headers}');
      }

      if (options.data != null) {
        logger.t('$_tag => ${options.data}');
      }
    }

    return handler.next(options.copyWith(extra: {"start-time": DateTime
        .now()
        .millisecondsSinceEpoch}));
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
      var msec = endTime
          .difference(startTime)
          .inMilliseconds;
      logger.t('$_tag <= ERROR ${err.requestOptions.uri} ($msec msec)');
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
    var msec = endTime
        .difference(startTime)
        .inMilliseconds;

    dynamic contentLength = response.headers['content-length']?.firstOrNull ?? _calculateContentLength(response);
    logger.t(
        '$_tag <= ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri} \'${response
            .statusMessage}\' ($contentLength bytes / $msec msec)');

    if (response.data != null) {
      if (response.data is Map) {
        logger.t('$_tag <= ${jsonEncode(response.data)}}');
      } else {
        logger.t('$_tag <= ${response.data}}');
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
