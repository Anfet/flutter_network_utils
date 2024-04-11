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

  final Property<String> buildProperty;
  final Property<String> proxyProperty;
  final _EnviromentSaveData _saveableData = _EnviromentSaveData();

  bool get requireRestart =>
      _saveableData.buildProperty.cachedValue != buildProperty.cachedValue || _saveableData.proxyProperty.cachedValue != proxyProperty.cachedValue;

  EnviromentConfigPart({
    this.name = 'enviroment',
    required this.buildProperty,
    required this.proxyProperty,
    this.title = 'Enviroment',
    this.customHostTitle = 'Host',
    this.proxyHostTitle = 'Proxy',
    this.clearButtonText = 'Clear',
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
    var requireRestart = this.requireRestart;
    await buildProperty.setValue(_saveableData.buildProperty.cachedValue);
    var build = await Build.load(buildProperty);
    if (requireRestart) {
      warn('enviroment changed to $build');
    }
    if (_saveableData.proxyProperty.cachedValue != proxyProperty.cachedValue) {
      await proxyProperty.setValue(_saveableData.proxyProperty.cachedValue);
    }
    return requireRestart;
  }
}

class _EnviromentSaveData implements SaveableData {
  final MemoryProperty<String> buildProperty = MemoryProperty('', '');
  final MemoryProperty<String> proxyProperty = MemoryProperty('', '');
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

  @override
  void initState() {
    reload();
    super.initState();
  }

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
              Text(widget.part.title, style: theme.titleStyle?.bold()),
              if (part.requireRestart) ...[
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
            childAspectRatio: 2,
            padding: EdgeInsets.zero,
            clipBehavior: Clip.none,
            children: [
              ...Enviroment.values.map(
                (enviroment) {
                  bool isSelected = enviroment.name == selectedBuild?.enviroment;
                  var host = require(Enviroments.enviroments[enviroment]).ifEmpty(customController.text);
                  Build build = Build(enviroment: enviroment.name, host: host);
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onBuildSelected(build),
                    child: _EnviromentTile(
                      isSelected: isSelected,
                      onBuildSelected: onBuildSelected,
                      model: build,
                    ),
                  );
                },
              ),
            ],
          ),
          if (selectedBuild?.enviroment == Enviroment.custom.name) const VSpacer(12),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.topCenter,
            child: selectedBuild?.enviroment == Enviroment.custom.name
                ? _HostEdit(
                    label: part.customHostTitle,
                    controller: customController,
                    hint: 'https://, 127.0.0.1',
                    onTextChanged: onCustomHostChanged,
                    suffixText: part.clearButtonText,
                  )
                : const SizedBox(),
          ),
          const VSpacer(12),
          _HostEdit(
            controller: proxyController,
            label: part.proxyHostTitle,
            hint: '0.0.0.0:8888',
            onTextChanged: onProxyChanged,
            suffixText: part.clearButtonText,
          ),
        ],
      ),
    );
  }

  Future<void> onBuildSelected(Build build) async {
    await build.save(part._saveableData.buildProperty);
    setState(() {
      selectedBuild = build;
    });
  }

  Future<void> onProxyChanged(String ip) async {
    var proxy = CustomProxy(ip);
    await proxy.save(part._saveableData.proxyProperty);
    setState(() {});
  }

  Future<void> onCustomHostChanged(String host) async {
    setState(() {
      selectedBuild = Build(enviroment: Enviroment.custom.name, host: host);
    });
    await selectedBuild?.save(part._saveableData.buildProperty);
  }

  Future<void> reload() async {
    var build = await Build.load(part._saveableData.buildProperty);
    var proxy = await CustomProxy.load(part._saveableData.proxyProperty);
    setState(() {
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
            Text(
              model.enviroment.toUpperCase(),
              style: theme.titleStyle
                  ?.bold()
                  .copyWith(color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSecondaryContainer),
            ),
            const VSpacer(8),
            Expanded(
              child: Text(model.host,
                  style: theme.labelStyle?.copyWith(
                    color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSecondaryContainer,
                  ),
                  overflow: TextOverflow.clip),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostEdit extends StatelessWidget {
  final TextEditingController controller;
  final String? suffixText;
  final ValueChanged<String>? onTextChanged;
  final String? hint;
  final String? label;

  const _HostEdit({
    required this.controller,
    this.suffixText,
    this.onTextChanged,
    this.hint,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      style: theme.textStyle,
      maxLines: 1,
      autocorrect: false,
      autofocus: false,
      keyboardType: TextInputType.text,
      onTapOutside: (event) {
        FocusScope.of(context).unfocus();
      },
      expands: false,
      decoration: InputDecoration(
        label: label != null ? Text(label!) : null,
        labelStyle: theme.titleStyle?.bold(),
        hintText: hint,
        constraints: theme.inputDecorationTheme.constraints,
        contentPadding: theme.inputDecorationTheme.contentPadding ?? EdgeInsets.zero,
        hintStyle: theme.inputDecorationTheme.hintStyle ?? theme.textStyle?.copyWith(color: theme.hintColor),
        errorStyle: theme.textTheme.labelMedium,
        isDense: theme.inputDecorationTheme.isDense,
        isCollapsed: theme.inputDecorationTheme.isCollapsed,
        filled: theme.inputDecorationTheme.filled,
        fillColor: theme.inputDecorationTheme.fillColor,
        border: theme.inputDecorationTheme.border,
        focusedBorder: theme.inputDecorationTheme.focusedBorder,
        enabledBorder: theme.inputDecorationTheme.enabledBorder,
        errorBorder: theme.inputDecorationTheme.errorBorder,
        focusedErrorBorder: theme.inputDecorationTheme.focusedErrorBorder,
        errorText: null,
        labelText: null,
        counterText: null,
        suffix: suffixText != null
            ? TextButton(
                style: ButtonStyle(
                  minimumSize: const MaterialStatePropertyAll(Size.zero),
                  padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  foregroundColor: MaterialStatePropertyAll(theme.colorScheme.onPrimary),
                ),
                child: Text(suffixText!, style: theme.labelStyle),
                onPressed: () {
                  controller.text = '';
                  onTextChanged?.call('');
                },
              )
            : null,
      ),
      onChanged: onTextChanged,
    );
  }
}
