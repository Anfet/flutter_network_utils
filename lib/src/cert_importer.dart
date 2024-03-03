import 'dart:convert';
import 'dart:io' as platform;

import 'package:flutter/services.dart';
import 'package:siberian_network/generated/assets.dart';

class CertImporter {
  CertImporter._();

  static Future<void> importCharleyCert({String asset = Assets.certsCharley}) async {
    var securityContext = platform.SecurityContext.defaultContext;
    String data = await rootBundle.loadString(asset);
    List<int> bytes = utf8.encode(data);
    securityContext.setTrustedCertificatesBytes(bytes);
  }
}
