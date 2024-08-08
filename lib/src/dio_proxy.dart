import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_commons/flutter_commons.dart';

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

  CustomProxyHttpOverride.direct({this.allowBadCertificates = true}) : proxy = CustomProxy();
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
    HttpOverrides.global = CustomProxyHttpOverride.direct();
  }

  @override
  String toString() {
    return url.isEmpty ? "DIRECT" : "PROXY $url";
  }

  Future<void> save(StorableProperty<String> property) async {
    return isValid ? property.setValue(url.toString()) : property.delete();
  }

  static CustomProxy from(String text) {
    final proxy = CustomProxy(text);
    return proxy;
  }

  static Future<CustomProxy> load(StorableProperty<String> property) async {
    final string = await property.getValue();
    final proxy = CustomProxy(string);
    return proxy;
  }

  static Future<void> configure(StorableProperty<String> property) async {
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
