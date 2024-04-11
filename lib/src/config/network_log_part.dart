import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:siberian_config/siberian_config.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_config/src/ext/theme_ext.dart';
import 'package:siberian_network/src/loggers/network_loggers.dart';

class NetworkLogPart with ChangeNotifier implements ConfigPart {
  @override
  final String name;
  final String title;

  final String fileDeletedText;

  final Property<bool> networkLogProperty;
  final VoidCallback onShowNetworkLog;
  final ValueSetter<bool>? onNetworkLogStateChange;

  NetworkLogPart({
    this.title = 'Enable network log',
    required this.name,
    required this.networkLogProperty,
    required this.onShowNetworkLog,
    this.onNetworkLogStateChange,
    this.fileDeletedText = 'File deleted'
  });

  @override
  Widget build(BuildContext context, {EdgeInsets? padding}) {
    return ListenableBuilder(
      listenable: this,
      builder: (context, child) {
        return _NetworkLogConfigPartWidget(
          part: this,
          padding: padding,
        );
      },
    );
  }

  @override
  FutureOr<void> init() async {
    await networkLogProperty.getValue();
  }
}

class _NetworkLogConfigPartWidget extends StatefulWidget {
  final NetworkLogPart part;
  final EdgeInsets? padding;

  const _NetworkLogConfigPartWidget({
    required this.part,
    this.padding,
  });

  @override
  State<_NetworkLogConfigPartWidget> createState() => _NetworkLogConfigPartWidgetState();
}

class _NetworkLogConfigPartWidgetState extends State<_NetworkLogConfigPartWidget> with MountedStateMixin {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkButton(
          padding: widget.padding,
          onTap: _toggleNetworkLog,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(widget.part.title, style: theme.titleStyle?.bold())),
              Transform.scale(
                scale: .9,
                child: AbsorbPointer(
                  child: CupertinoSwitch(
                    activeColor: theme.colorScheme.primary,
                    onChanged: (value) {},
                    value: widget.part.networkLogProperty.cachedValue,
                  ),
                ),
              ),
            ],
          ),
        ),
        const VSpacer(4),
        AbsorbPointer(
          absorbing: !widget.part.networkLogProperty.cachedValue,
          child: Opacity(
            opacity: widget.part.networkLogProperty.cachedValue ? 1.0 : .5,
            child: Padding(
              padding: (widget.padding ?? EdgeInsets.zero).copyWith(top: 0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(onPressed: widget.part.onShowNetworkLog, icon: const Icon(Icons.remove_red_eye)),
                  IconButton(onPressed: _shareNetworkLog, icon: const Icon(Icons.share)),
                  IconButton(onPressed: _clearNetworkLog, icon: const Icon(Icons.delete_outline)),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  Future<void> _shareNetworkLog() async {
    var file = await NetworkLoggers.networkLogFile;
    var text = await file.readAsString();
    Share.share(text);
  }

  Future<void> _clearNetworkLog() async {
    var file = await NetworkLoggers.networkLogFile;
    file.delete().ignore();
    showToast(widget.part.fileDeletedText);
  }

  Future<void> _toggleNetworkLog() async {
    await widget.part.networkLogProperty.setValue(!widget.part.networkLogProperty.cachedValue);
    setState(() {});
    var isEnabled = widget.part.networkLogProperty.cachedValue;
    NetworkLoggers.networkToFileInterceptor.isEnabled = isEnabled;
    widget.part.onNetworkLogStateChange?.call(isEnabled);
  }
}
