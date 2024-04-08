import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_logger/siberian_logger.dart';
import 'package:siberian_network/src/logging_interceptor.dart';

class NetworkLoggers {
  NetworkLoggers._();

  static LoggingInterceptor? _networkToConsoleInterceptor;

  static LoggingInterceptor get networkToConsoleInterceptor => require(_networkToConsoleInterceptor);

  static LoggingInterceptor? _networkToFileInterceptor;

  static LoggingInterceptor get networkToFileInterceptor => require(_networkToFileInterceptor);

  static Future<File> get networkLogFile async {
    final cacheDir = await getApplicationCacheDirectory();
    final file = File('${cacheDir.path}/network.log');
    return file;
  }

  static Future<void> initInterceptors({
    required bool logToFile,
    required bool logToConsole,
    bool truncateConsoleMessages = true,
  }) async {
    _networkToFileInterceptor = LoggingInterceptor(
      name: 'file_logger',
      isEnabled: logToFile,
      truncateMessages: false,
      Logger(
        printer: CustomLogger(isColored: false),
        output: FileOutput(file: await networkLogFile),
        filter: ProductionFilter(),
      ),
    );


    _networkToConsoleInterceptor = LoggingInterceptor(
      name: 'console_logger',
      truncateMessages: truncateConsoleMessages,
      Logger(
        printer: CustomLogger(isColored: false),
        filter: DevelopmentFilter(),
      ),
    );

    networkToConsoleInterceptor.isEnabled = logToConsole;
  }
}
