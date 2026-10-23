import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates the HTTP client of the app.
///
/// The development server uses a self-signed certificate (ADR-0006). In a debug
/// build only, the certificate of [developmentHost] is accepted; a release build
/// trusts the certificates of the system and nothing else.
http.Client createHttpClient({required String developmentHost}) {
  if (!kDebugMode) {
    return http.Client();
  }
  final inner = HttpClient()
    ..badCertificateCallback = (
      X509Certificate certificate,
      String host,
      int port,
    ) => host == developmentHost;
  return IOClient(inner);
}
