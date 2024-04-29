import 'dart:async';
import 'dart:convert';

import 'package:example/src/demo_screen.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:siberian_logger/siberian_logger.dart';
import 'package:siberian_network/siberian_network.dart';

void main() {
  runZonedGuarded(() async {
    await WidgetsFlutterBinding.ensureInitialized();
    await NetworkLoggers.initInterceptors(logToFile: true, logToConsole: true);
    runApp(const ExampleApp());
  }, (error, stack) {
    logMessage(error, error: error, stack: stack, level: Level.error);
  });
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  @override
  Widget build(BuildContext context) {
    var theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
    );

    return OKToast(
      backgroundColor: Colors.black,
      position: const ToastPosition(align: Alignment.bottomCenter, offset: -70),
      dismissOtherOnShow: true,
      radius: 8,
      textPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      textStyle: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimary),
      textAlign: TextAlign.center,
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: DemoScreen(),
      ),
    );
  }
}
