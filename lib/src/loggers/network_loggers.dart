import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_network/src/logging_interceptor.dart';

class NetworkLoggers {
  NetworkLoggers._();

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
  }) async {
    _networkToFileInterceptor ??= LoggingInterceptor(
      name: 'file_logger',
      isEnabled: logToFile,
      Logger(
        printer: CustomLogger(truncateMessages: false),
        output: FileOutput(file: await networkLogFile),
        filter: ProductionFilter(),
      ),
    );
    _networkToFileInterceptor?.logger.t('${_networkToFileInterceptor?.name} ------- INIT --------');

    networkToConsoleInterceptor.isEnabled = logToConsole;
    networkToConsoleInterceptor.logger.t('${networkToConsoleInterceptor.name} ------- INIT --------');
  }

  static LoggingInterceptor networkToConsoleInterceptor = LoggingInterceptor(
    name: 'console_logger',
    Logger(
      printer: CustomLogger(truncateMessages: false),
      filter: DevelopmentFilter(),
    ),
  );
}
