import 'package:http/http.dart' as http;

/// Creates the HTTP client of the app on a platform without `dart:io` (the
/// web). The browser decides which certificates it trusts.
http.Client createHttpClient({required String developmentHost}) =>
    http.Client();
