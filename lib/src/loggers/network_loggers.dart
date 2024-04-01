import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_network/src/logging_interceptor.dart';

class NetworkInterceptors {
  NetworkInterceptors._();

  static LoggingInterceptor? _networkLogFileInterceptor;

  static LoggingInterceptor get networkLogFileInterceptor => require(networkLogFileInterceptor);

  static Future<void> initInterceptors() async {
    final cacheDir = await getApplicationCacheDirectory();
    final file = File('${cacheDir.path}/network.log');

    _networkLogFileInterceptor ??= LoggingInterceptor(
      Logger(
        printer: CustomLogger(truncateMessages: false),
        output: FileOutput(file: file),
        filter: ProductionFilter(),
      ),
    );
  }

  static LoggingInterceptor consoleInterceptor = LoggingInterceptor(
    Logger(
      printer: CustomLogger(truncateMessages: true),
      filter: DevelopmentFilter(),
    ),
  );
}
