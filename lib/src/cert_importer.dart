import 'dart:convert';
import 'dart:io' as platform;

import 'package:flutter/services.dart';

class CertImporter {
  CertImporter._();

  static const charleyCertLibraryPath = 'packages/flutter_network_utils/certs/charley.pem';
  static const charleyCertPath = 'assets/certs/charley.pem';

  static Future<void> importCharleyCert({required String asset}) async {
    var securityContext = platform.SecurityContext.defaultContext;
    String data = await rootBundle.loadString(asset);
    List<int> bytes = utf8.encode(data);
    securityContext.setTrustedCertificatesBytes(bytes);
  }
}
