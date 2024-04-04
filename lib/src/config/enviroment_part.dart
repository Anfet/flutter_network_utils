import 'dart:async';

import 'package:flutter/material.dart';
import 'package:siberian_config/src/ext/theme_ext.dart';
import 'package:siberian_config/src/parts/config_part.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_logger/siberian_logger.dart';
import 'package:siberian_network/siberian_network.dart';

class EnviromentConfigPart with ChangeNotifier, Logging implements ConfigPart, SaveablePart {
  @override
  final String name;

  final String title;
  final String customHostTitle;
  final String proxyHostTitle;
  final String clearButtonText;
  final String restartRequiredText;

  final Property<String> buildProperty;
  final Property<String> proxyProperty;
  final _EnviromentSaveData _saveableData = _EnviromentSaveData();

  EnviromentConfigPart({
    this.name = 'enviroment',
    required this.buildProperty,
    required this.proxyProperty,
    this.title = 'Enviroment',
    this.customHostTitle = 'Custom host',
    this.proxyHostTitle = 'Proxy',
    this.clearButtonText = 'Clear',
    this.restartRequiredText = 'Restart required',
  });

  @override
  Widget build(BuildContext context, {EdgeInsets? padding}) => ListenableBuilder(
        listenable: this,
        builder: (context, child) {
          return _EnviromentConfigPart(
            part: this,
            padding: padding,
          );
        },
      );

  @override
  FutureOr<void> init() async {
    await buildProperty.getValue();
    await proxyProperty.getValue();
    await _saveableData.buildProperty.setValue(buildProperty.cachedValue);
    await _saveableData.proxyProperty.setValue(proxyProperty.cachedValue);
    notifyListeners();
  }

  @override
  FutureOr<bool> save() async {
    var requireRestart = _saveableData.buildProperty.cachedValue != buildProperty.cachedValue;
    await buildProperty.setValue(_saveableData.buildProperty.cachedValue);
    var build = await Build.load(buildProperty);
    if (requireRestart) {
      warn('enviroment changed to $build');
    }
    if (_saveableData.proxyProperty.cachedValue != proxyProperty.cachedValue) {
      await proxyProperty.setValue(_saveableData.proxyProperty.cachedValue);
      await CustomProxy.configure(proxyProperty);
    }
    return requireRestart;
  }
}

class _EnviromentSaveData implements SaveableData {
  final MemoryProperty<String> buildProperty = MemoryProperty('');
  final MemoryProperty<String> proxyProperty = MemoryProperty('');
}

class _EnviromentConfigPart extends StatefulWidget {
  final EnviromentConfigPart part;
  final EdgeInsets? padding;

  const _EnviromentConfigPart({
    required this.part,
    this.padding,
  });

  @override
  State<_EnviromentConfigPart> createState() => _EnviromentConfigPartState();
}

class _EnviromentConfigPartState extends State<_EnviromentConfigPart> with MountedStateMixin {
  EnviromentConfigPart get part => widget.part;

  final TextEditingController customController = TextEditingController();
  final TextEditingController proxyController = TextEditingController();

  Build? selectedBuild;

  bool get requireRestart => part._saveableData.buildProperty.cachedValue != part.buildProperty.cachedValue;

  @override
  void didUpdateWidget(covariant _EnviromentConfigPart oldWidget) {
    reload();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    customController.dispose();
    proxyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(widget.part.title, style: theme.titleStyle?.bold())),
              if (requireRestart) ...[
                Text(part.restartRequiredText, style: theme.titleStyle?.copyWith(color: theme.colorScheme.error)),
                const HSpacer(4),
                Icon(Icons.info_outline, color: theme.colorScheme.error, size: (theme.titleStyle?.fontSize ?? 1.0) * 1.25),
              ],
            ],
          ),
          const VSpacer(12),
          GridView.count(
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            padding: EdgeInsets.zero,
            clipBehavior: Clip.none,
            children: [
              ...Enviroment.values.map(
                (enviroment) {
                  bool isSelected = enviroment.name == selectedBuild?.enviroment;
                  var host = require(Enviroments.enviroments[enviroment]).ifEmpty(customController.text);
                  Build build = Build(enviroment: enviroment.name, host: host);
                  return PhysicalModel(
                    color: Colors.transparent,
                    elevation: isSelected ? 0 : 2,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onBuildSelected(build),
                      child: _EnviromentTile(
                        isSelected: isSelected,
                        onBuildSelected: onBuildSelected,
                        model: build,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...selectedBuild?.enviroment == Enviroment.custom.name
                    ? [
                        const VSpacer(12),
                        if (part.customHostTitle.isNotEmpty) ...[
                          Text(part.customHostTitle, style: theme.titleStyle?.bold()),
                        ],
                        TextField(
                          controller: customController,
                          style: theme.textStyle,
                          maxLines: 1,
                          autocorrect: false,
                          autofocus: false,
                          keyboardType: TextInputType.text,
                          onTapOutside: (event) {
                            FocusScope.of(context).unfocus();
                          },
                          decoration: InputDecoration(
                            hintText: 'https://, 127.0.0.1',
                            hintStyle: theme.textStyle?.copyWith(color: theme.hintColor),
                            constraints: const BoxConstraints(
                              maxHeight: 40,
                            ),
                            errorText: null,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            suffix: TextButton(
                              style: ButtonStyle(
                                minimumSize: const MaterialStatePropertyAll(Size.zero),
                                padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                foregroundColor: MaterialStatePropertyAll(theme.colorScheme.onPrimary),
                              ),
                              child: Text(part.clearButtonText, style: theme.labelStyle),
                              onPressed: () {
                                customController.text = '';
                              },
                            ),
                          ),
                          onChanged: onCustomHostChanged,
                        ),
                      ]
                    : [],
              ],
            ),
          ),
          const VSpacer(12),
          if (part.proxyHostTitle.isNotEmpty) ...[
            Text(part.proxyHostTitle, style: theme.titleStyle?.bold()),
          ],
          TextField(
            controller: proxyController,
            style: theme.textStyle,
            maxLines: 1,
            autocorrect: false,
            autofocus: false,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: '0.0.0.0:8888',
              hintStyle: theme.textStyle?.copyWith(color: theme.hintColor),
              constraints: const BoxConstraints(
                maxHeight: 40,
              ),
              errorText: null,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              suffix: TextButton(
                style: ButtonStyle(
                  minimumSize: const MaterialStatePropertyAll(Size.zero),
                  padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  // backgroundColor: MaterialStatePropertyAll(Colors.green),
                  foregroundColor: MaterialStatePropertyAll(theme.colorScheme.onPrimary),
                ),
                child: Text(part.clearButtonText, style: theme.labelStyle),
                onPressed: () {
                  proxyController.text = '';
                },
              ),
            ),
            onChanged: onProxyChanged,
          ),
        ],
      ),
    );
  }

  Future<void> onBuildSelected(Build build) async {
    await build.save(part._saveableData.buildProperty);
    setStateChecked(() {
      selectedBuild = build;
    });
  }

  Future<void> onProxyChanged(String ip) async {
    var proxy = CustomProxy(ip);
    await proxy.save(part._saveableData.proxyProperty);
  }

  Future<void> onCustomHostChanged(String host) async {
    selectedBuild = Build(enviroment: Enviroment.custom.name, host: host);
    await selectedBuild?.save(part._saveableData.buildProperty);
  }

  Future<void> reload() async {
    var build = await Build.load(part._saveableData.buildProperty);
    var proxy = await CustomProxy.load(part._saveableData.proxyProperty);
    setStateChecked(() {
      customController.text = build.enviroment == Enviroment.custom.name ? build.host : '';
      proxyController.text = proxy.isValid ? proxy.url : '';
      selectedBuild = build;
    });
  }
}

class _EnviromentTile extends StatelessWidget {
  final Build model;
  final bool isSelected;
  final ValueSetter<Build> onBuildSelected;

  const _EnviromentTile({
    required this.isSelected,
    required this.onBuildSelected,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkButton(
      backgroundColor: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: () => onBuildSelected(require(model)),
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(model.enviroment.toUpperCase(), style: theme.titleStyle?.bold()),
            const VSpacer(8),
            Expanded(
              child: Text(model.host, style: theme.labelStyle, overflow: TextOverflow.clip),
            ),
          ],
        ),
      ),
    );
  }
}
