import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_network_utils/flutter_network_utils.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> with MountedCheck {
  late final Dio dio;
  Loadable<Map> localeInfo = const Loadable.idle();
  Loadable<String> lorem = const Loadable.idle();
  Loadable complex = const Loadable.idle();
  Loadable cancel = const Loadable.idle();

  final QueryScheduler scheduler = QueryScheduler();
  late final NetworkCallExecutor executor;

  @override
  void dispose() {
    scheduler.dispose();
    super.dispose();
  }

  @override
  void initState() {
    dio = Dio(BaseOptions(
      contentType: Headers.jsonContentType,
      receiveTimeout: const Duration(minutes: 1),
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      followRedirects: true,
      receiveDataWhenStatusError: true,
      responseDecoder: (responseBytes, options, responseBody) {
        return utf8.decode(responseBytes);
      },
    ));

    dio.interceptors.addAll([
      NetworkLoggers.networkToConsoleInterceptor,
      NetworkLoggers.networkToFileInterceptor,
    ]);

    executor = NetworkCallExecutor(dio);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NavbarSpacer.top(),
            const VSpacer(16),
            Text('Siberian network example app', style: Theme.of(context).textTheme.titleMedium?.bold(), textAlign: TextAlign.center),
            const VSpacer(16),
            ElevatedButton(onPressed: () => gotoNetworkLog(context), child: const Text('Show network log')),
            const VSpacer(8),
            ElevatedButton(
              onPressed: localeInfo.isLoading ? null : () => fetchLocaleInfo(),
              child: localeInfo.isLoading ? const CupertinoActivityIndicator() : const Text('Fetch locale'),
            ),
            const VSpacer(8),
            ElevatedButton(
              onPressed: lorem.isLoading ? null : () => fetchLorem(),
              child: lorem.isLoading ? const CupertinoActivityIndicator() : const Text('Fetch lorem'),
            ),
            const VSpacer(8),
            ElevatedButton(
              onPressed: complex.isLoading ? null : () => fetchComplex(),
              child: complex.isLoading ? const CupertinoActivityIndicator() : const Text('Schedule complex'),
            ),
            const VSpacer(8),
            ElevatedButton(
              onPressed: cancel.isLoading ? null : () => fetchAndCancel(),
              child: cancel.isLoading ? const CupertinoActivityIndicator() : const Text('Cancel request'),
            ),
            const VSpacer(8),
            ElevatedButton(
              onPressed: scheduleTasks,
              child: const Text('ScheduleTasks'),
            ),
            const Spacer(),
            const NavbarSpacer.bottom(),
          ],
        ),
      ),
    );
  }

  void gotoNetworkLog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/network_log'),
        builder: (context) => NetworkLogScreeen(
          onShare: (path) => Share.shareXFiles([XFile(path, name: 'network.txt', mimeType: 'text/plain')], text: 'Network log file'),
          onToast: (text) => showToast(text),
        ),
      ),
    );
  }

  Future fetchLocaleInfo() async {
    setState(() => localeInfo = localeInfo.loading());
    try {
      var data = await dio.get('http://ip-api.com/json/').then((r) => r.data);
      setState(() => localeInfo = localeInfo.result(data));
    } finally {
      setState(() => localeInfo = localeInfo.idle());
    }
  }

  Future fetchLorem() async {
    setState(() => lorem = lorem.loading());
    try {
      int paragraphs = 1 + randomizer.nextInt(5);
      String length = ['short', 'medium', 'long'].randomElement;
      var data = await dio.get('https://loripsum.net/api/$paragraphs/$length').then((r) => r.data);
      setState(() => lorem = lorem.result(data));
    } finally {
      setState(() => lorem = lorem.idle());
    }
  }

  Future fetchComplex() async {
    setState(() => complex = complex.loading());
    try {
      scheduler.enqueue(() => executor.get('http://ip-api.com/json/'));
      scheduler.enqueue(() => executor.get('https://api.api-ninjas.com/v1/loremipsum'));
      setState(() => complex = complex.result());
    } finally {
      setState(() => complex = complex.idle());
    }
  }

  Future fetchAndCancel() async {
    setState(() => cancel = cancel.loading());
    try {
      var request = scheduler.enqueue(() => Future.delayed(const Duration(seconds: 5)), tag: 'x');
      var future = request.future;
      await Future.wait(
        [
          Future.sync(() async => scheduler.drop(ids: [request.id])),
          future.then((_) => logMessage('WAIT RESULT')),
        ],
        eagerError: true,
      );
      setState(() => cancel = cancel.result());
    } catch (ex) {
      showToast(ex.toString());
    } finally {
      setState(() => cancel = cancel.idle());
    }
  }

  void scheduleTasks() {
    var count = 5 + randomizer.nextInt(20);
    for (var i = 0; i < count; i++) {
      var request = scheduler.enqueue(() => Future.delayed(Duration(seconds: randomizer.nextInt(10))), priority: QueryPriority.values.randomElement);
      request.future.then((_) => logMessage('request ${request.id} done'));
    }
  }
}
