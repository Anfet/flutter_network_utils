import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter_commons/flutter_commons.dart';
import 'package:flutter_network_utils/src/interceptors/logging_interceptor.dart';

class NetworkLoggers {
  NetworkLoggers._();

  static const networkFileName = 'network_log.txt';

  static LoggingInterceptor? _networkToConsoleInterceptor;

  static LoggingInterceptor get networkToConsoleInterceptor => require(_networkToConsoleInterceptor);

  static LoggingInterceptor? _networkToFileInterceptor;

  static LoggingInterceptor get networkToFileInterceptor => require(_networkToFileInterceptor);

  static Future<File> get networkLogFile async {
    final cacheDir = await getApplicationCacheDirectory();
    final file = File('${cacheDir.path}/$networkFileName');
    return file;
  }

  static Future<void> clearFileLog() => networkLogFile.then((file) => file.writeAsString('', flush: true, mode: FileMode.write));

  static void overrideInterceptors({
    LoggingInterceptor? consoleInterception,
    LoggingInterceptor? fileInterceptor,
  }) {
    _networkToConsoleInterceptor = consoleInterception;
    _networkToFileInterceptor = fileInterceptor;
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
      isEnabled: logToConsole,
      Logger(
        printer: CustomLogger(isColored: false),
        filter: DevelopmentFilter(),
      ),
    );
  }
}
