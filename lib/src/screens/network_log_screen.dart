import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    loadNetworkLog();
    super.initState();
  }

  @override
  void dispose() {
    scrollController.dispose();
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
            onPressed: () async {
              await loadNetworkLog();
              _scrollToBottom();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
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
      floatingActionButton: FloatingActionButton(
        elevation: 4,
        onPressed: _scrollToBottom,
        child: Icon(
          Icons.keyboard_arrow_down_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 40,
        ),
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
                  thumbVisibility: true,
                  thumbColor: Theme.of(context).colorScheme.primary,
                  thickness: 4,
                  scrollbarOrientation: ScrollbarOrientation.right,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        text.value ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: widget.fontFamily),
                      ),
                    ),
                  ),
                ),
              ),
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
      this.text = text.asValue;
    });
  }

  void _scrollToBottom() {
    scrollController.animateTo(scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.linear);
  }
}
