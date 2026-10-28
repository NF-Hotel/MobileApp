import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:mobil_application/domain/result.dart';

/// Gives the access token to send, or null when nobody is signed in.
typedef TokenProvider = String? Function();

/// Calls the LoginApi of this repository (`api/Program.cs`).
///
/// It sends the access token as `Authorization: Bearer`, reads the plain JSON
/// the API answers with, turns a status into a [FailureKind], and tells
/// [onUnauthorized] when the token is no longer accepted so that the app can
/// return to the sign-in.
class ApiClient {
  /// Creates the client.
  ApiClient({
    required http.Client httpClient,
    required this._baseUri,
    required this._tokenProvider,
    required this._onUnauthorized,
    this.timeout = const Duration(seconds: 15),
  }) : _client = httpClient;

  /// How long a call may take before it counts as a network failure.
  final Duration timeout;

  final http.Client _client;
  final Uri _baseUri;
  final TokenProvider _tokenProvider;
  final void Function() _onUnauthorized;

  /// A GET; [parse] turns the JSON body into the result.
  Future<Result<T>> get<T>(String path, T Function(Object? json) parse) =>
      send('GET', path, parse: parse);

  /// Sends [method] to [path] with an optional JSON [body]. Without [parse] the
  /// result holds null: most writes of the API answer an empty 200.
  Future<Result<T>> send<T>(
    String method,
    String path, {
    Object? body,
    T Function(Object? json)? parse,
  }) async {
    final token = _tokenProvider();
    final request = http.Request(method, _uri(path))
      ..headers['Accept'] = 'application/json';
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on Exception {
      // A timeout, a refused connection, a socket or a TLS error.
      return Failed(const ApiFailure(FailureKind.network));
    }
    return _result(response, parse, signedIn: token != null);
  }

  Uri _uri(String path) {
    final base = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(path: '$base$path');
  }

  Result<T> _result<T>(
    http.Response response,
    T Function(Object? json)? parse, {
    required bool signedIn,
  }) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      try {
        final json = response.body.isEmpty
            ? null
            : jsonDecode(utf8.decode(response.bodyBytes));
        return Success(parse == null ? null as T : parse(json));
      } on FormatException {
        return Failed(const ApiFailure(FailureKind.server));
      }
    }

    // A 401 without a token is the sign-in refusing the email or password.
    if (status == 401 && signedIn) {
      _onUnauthorized();
    }
    return Failed(
      ApiFailure(switch (status) {
        401 when signedIn => FailureKind.unauthorized,
        401 => FailureKind.invalidCredentials,
        403 => FailureKind.forbidden,
        404 => FailureKind.notFound,
        400 || 409 => FailureKind.rejected,
        _ => FailureKind.server,
      }),
    );
  }
}
