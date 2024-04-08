import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/rendering/viewport_offset.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_network/siberian_network.dart';

class NetworkLogScreeen extends StatefulWidget {
  final String textIfEmpty;
  final String deleteToastMessage;
  final String fontFamily;

  const NetworkLogScreeen({
    super.key,
    this.textIfEmpty = 'No network logs',
    this.deleteToastMessage = 'Network log cleared',
    this.fontFamily = 'SpaceMono',
  });

  @override
  State<NetworkLogScreeen> createState() => _NetworkLogScreeenState();
}

class _NetworkLogScreeenState extends State<NetworkLogScreeen> with MountedStateMixin {
  Loadable<String> text = const Loadable.loading();
  final scrollController = ScrollController();

  Timer? timer;

  @override
  void initState() {
    loadNetworkLog();
    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: false,
        title: Text('Network log', style: Theme.of(context).textTheme.titleSmall?.medium()),
        actions: [
          IconButton(
            onPressed: () {
              if (timer?.isActive == true) {
                cancelTimer();
                markNeedsRebuild();
              } else {
                scheduleTimer();
              }
            },
            icon: Icon(timer?.isActive == true ? Icons.pause : Icons.play_arrow),
            tooltip: timer?.isActive == true ? 'Pause watch' : 'Resume watch',
          ),
          IconButton(
            onPressed: () {
              Share.share(text.value ?? '');
            },
            icon: const Icon(Icons.share),
            tooltip: 'Share whole log',
          ),
          IconButton(
            onPressed: () async {
              NetworkLoggers.networkLogFile.then((file) => file.delete()).ignore();
              showToast(widget.deleteToastMessage);
              setState(() {
                text = const Loadable('');
              });
            },
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete log file',
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (text.isLoading) {
            return const Center(child: CupertinoActivityIndicator(radius: 24));
          }

          if (text.value == '') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(widget.textIfEmpty, style: Theme.of(context).textTheme.bodySmall?.medium()),
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: RawScrollbar(
                  controller: scrollController,
                  scrollbarOrientation: ScrollbarOrientation.right,
                  trackVisibility: true,
                  trackColor: Theme.of(context).colorScheme.primary,
                  radius: const Radius.circular(4),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.vertical,
                    child: RawScrollbar(
                      trackVisibility: true,
                      trackColor: Theme.of(context).colorScheme.primary,
                      thumbColor: Theme.of(context).colorScheme.primary,
                      radius: const Radius.circular(4),
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          text.value ?? '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: widget.fontFamily),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text('You can select parts of text to share', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
              const VSpacer(12),
              const NavbarSpacer.bottom(),
            ],
          );
        },
      ),
    );
  }

  Future<void> loadNetworkLog() async {
    var file = await NetworkLoggers.networkLogFile;
    var text = file.existsSync() ? await file.readAsString() : '';

    setState(() {
      var jumpToLast = scrollController.hasClients ? scrollController.position.maxScrollExtent == scrollController.offset : false;
      this.text = text.asValue;
      if (jumpToLast) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    scheduleTimer();
  }

  void scheduleTimer() {
    cancelTimer();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      loadNetworkLog();
    });
    markNeedsRebuild();
  }

  void cancelTimer() => timer?.cancel();
}
