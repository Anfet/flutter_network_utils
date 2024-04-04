import 'dart:io';

import 'package:flutter/material.dart';
import 'package:siberian_core/siberian_core.dart';
import 'package:siberian_logger/siberian_logger.dart';

const _tag = "CustomProxy";

class CustomProxyHttpOverride extends HttpOverrides {
  final CustomProxy proxy;
  final bool allowBadCertificates;

  CustomProxyHttpOverride.proxy(this.proxy, {this.allowBadCertificates = true});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    var client = super.createHttpClient(context);
    client.findProxy = (uri) => proxy.toString();
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => allowBadCertificates;
    return client;
  }

  CustomProxyHttpOverride.dicrect({this.allowBadCertificates = true}) : proxy = CustomProxy();
}

@immutable
class CustomProxy with Logging {
  late final String url;

  bool get isValid {
    return url.isNotEmpty;
  }

  CustomProxy([String? url]) {
    this.url = url ?? '';
  }

  void enable() {
    HttpOverrides.global = CustomProxyHttpOverride.proxy(this);
  }

  static void disable() {
    HttpOverrides.global = CustomProxyHttpOverride.dicrect();
  }

  @override
  String toString() {
    return url.isEmpty ? "DIRECT" : "PROXY $url";
  }

  Future<void> save(Property<String> property) async {
    return isValid ? property.setValue(url.toString()) : property.delete();
  }

  static Future<CustomProxy> load(Property<String> property) async {
    final string = await property.getValue();
    final proxy = CustomProxy(string);
    return proxy;
  }

  static Future<void> configure(Property<String> property) async {
    try {
      final proxy = await CustomProxy.load(property);
      if (proxy.isValid) {
        proxy.enable();
        proxy.trace('Proxy reconfigured to: $proxy', tag: _tag);
      } else {
        proxy.warn('No proxy defined', tag: _tag);
        CustomProxy.disable();
      }
    } catch (ex) {
      CustomProxy.disable();
    }
  }
}
