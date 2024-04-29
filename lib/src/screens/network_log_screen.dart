import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_network/siberian_network.dart';

class NetworkLogScreeen extends StatefulWidget {
  final String fontFamily;
  final TypedCallback<String>? onToast;
  final TypedCallback<String>? onShare;

  const NetworkLogScreeen({
    super.key,
    this.fontFamily = 'SpaceMono',
    this.onShare,
    this.onToast,
  });

  @override
  State<NetworkLogScreeen> createState() => _NetworkLogScreeenState();
}

class _NetworkLogScreeenState extends State<NetworkLogScreeen> with MountedStateMixin {
  Loadable<List<String>> lines = const Loadable.loading();

  bool isTooLarge = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) => reloadLog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight ?? 40,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        forceMaterialTransparency: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        scrolledUnderElevation: 4,
        elevation: 4,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        centerTitle: false,
        title: SizedBox(
          height: Theme.of(context).appBarTheme.toolbarHeight ?? 40,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              children: [
                const HSpacer(4),
                const Icon(CupertinoIcons.left_chevron, size: 28),
                // HSpacer(4),
                Text('Network log'.toUpperCase(), style: Theme.of(context).textTheme.bodySmall?.w400()),
              ],
            ),
          ),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (lines.isLoading) {
            return const Center(child: CupertinoActivityIndicator(radius: 12));
          }

          if (lines.requireValue.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text('No network logs', style: Theme.of(context).textTheme.bodySmall?.medium()),
              ),
            );
          }

          var logTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: widget.fontFamily);
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 12, right: 100),
                        child: SelectableText.rich(
                          TextSpan(
                            style: logTextStyle,
                            children: lines.valueOr([]).map((line) => spanFromLine(line, style: logTextStyle)).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (isTooLarge) ...[
                      const VSpacer(16),
                      const Text('File size is too large for log (> 64kb). Only last entries are shown ', textAlign: TextAlign.center),
                      const VSpacer(16),
                    ],
                    const NavbarSpacer.bottom(),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Card(
                  elevation: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: reloadLog,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh',
                      ),
                      if (widget.onShare != null)
                        IconButton(
                          onPressed: shareLog,
                          icon: const Icon(Icons.share),
                          tooltip: 'Share log',
                        ),
                      if (widget.onToast != null)
                        IconButton(
                          onPressed: onClearLog,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete log file',
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  TextSpan spanFromLine(String line, {TextStyle? style}) {
    var text = line;
    final time = boldRegex.firstMatch(text);
    if (time != null) {
      text = line.substring(time.end);
    }

    var method = methodReges.firstMatch(text);
    String? preMethod = method?.let((it) {
      var result = text.substring(0, it.start);
      text = text.substring(it.end);
      return result;
    });

    return TextSpan(
      style: style,
      children: [
        if (time != null) TextSpan(text: time.group(0).toString(), style: style?.w300()),
        if (preMethod != null) ...[
          TextSpan(text: preMethod, style: style),
          TextSpan(
            text: require(method).group(0).toString(),
            style: style?.w900().let(
              (it) {
                var methodName = require(method).group(0).toString();
                return it.copyWith(
                  color: switch (methodName) {
                    'GET' => Colors.green.withGreen(128),
                    'POST' => Colors.blue,
                    'PUT' => Colors.blueAccent,
                    'PATCH' => Colors.orangeAccent,
                    'DELETE' => Colors.red,
                    'ERROR' => Colors.red,
                    _ => null,
                  },
                );
              },
            ),
          ),
        ],
        TextSpan(text: '$text\n', style: style),
      ],
    );
  }

  Future<void> reloadLog() async {
    var file = await NetworkLoggers.networkLogFile;
    if (!file.existsSync()) {
      setState(() {
        this.lines = const Loadable([]);
      });

      return;
    }

    var size = file.lengthSync();
    isTooLarge = size > _largeLogSize;
    var lines = await compute<File, Iterable<String>>((file) async {
      var lines = await file.readAsLines();
      while (lines.join('\n').length > _largeLogSize) {
        lines.removeAt(0);
      }

      return lines;
    }, file);

    setState(() {
      this.lines = lines.toList().asValue;
    });
  }

  void onClearLog() {
    NetworkLoggers.clearFileLog().then((value) => reloadLog()).ignore();
    widget.onToast?.call('Network log cleared');
  }

  Future<void> shareLog() async {
    widget.onShare?.call(await NetworkLoggers.networkLogFile.then((file) => file.path));
  }
}

const int _largeLogSize = 64 * kb;
// final boldRegex = RegExp(r'(.+) (<=|=>)');
final boldRegex = RegExp(r'((\d{2})[:.]{1}){3}(\d{3})');
final methodReges = RegExp(r'(GET|POST|PATCH|PUT|DELETE|OPTIONS|ERROR)');
