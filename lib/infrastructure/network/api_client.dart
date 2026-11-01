import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:mobil_application/domain/result.dart';

/// Gives the staff token to send, or null when nobody is signed in.
typedef TokenProvider = String? Function();

/// Calls the NF Hotel API (ADR-0015).
///
/// It sends the staff token in `X-Staff-Token` and nothing in `Authorization`:
/// the token of the web application is not in the app. It reads the envelope
/// `{ "value": ..., "errors": [...] }`, turns a status into a [FailureKind],
/// and tells [onUnauthorized] when the token is no longer accepted so that the
/// app can return to the sign-in.
class ApiClient {
  /// Creates the client.
  ApiClient({
    required http.Client httpClient,
    required this._baseUri,
    required this._tokenProvider,
    required this._onUnauthorized,
    this.timeout = const Duration(seconds: 15),
  }) : _client = httpClient;

  /// The name of the header with the staff token.
  static const String staffTokenHeader = 'X-Staff-Token';

  /// The code of a wrong user name or password.
  static const String invalidCredentialsCode = 'staff.invalid_credentials';

  /// How long a call may take before it counts as a network failure.
  final Duration timeout;

  final http.Client _client;
  final Uri _baseUri;
  final TokenProvider _tokenProvider;
  final void Function() _onUnauthorized;

  /// A GET; [parse] turns the `value` of the envelope into the result.
  Future<Result<T>> get<T>(String path, T Function(Object? value) parse) =>
      _send('GET', path, parse);

  /// A POST with an optional JSON [body] and [query].
  Future<Result<T>> post<T>(
    String path,
    T Function(Object? value) parse, {
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) => _send('POST', path, parse, body: body, query: query);

  Future<Result<T>> _send<T>(
    String method,
    String path,
    T Function(Object? value) parse, {
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    final uri = _uri(path, query);
    final headers = <String, String>{'Accept': 'application/json'};
    final token = _tokenProvider();
    if (token != null) {
      headers[staffTokenHeader] = token;
    }

    try {
      final http.Response response;
      if (method == 'GET') {
        response = await _client.get(uri, headers: headers).timeout(timeout);
      } else {
        headers['Content-Type'] = 'application/json';
        response = await _client
            .post(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(timeout);
      }
      return _result(response, parse);
    } on TimeoutException {
      return Failed(const ApiFailure(FailureKind.network));
    } on http.ClientException {
      return Failed(const ApiFailure(FailureKind.network));
    } on Exception {
      // A socket or a TLS error that the HTTP client did not wrap.
      return Failed(const ApiFailure(FailureKind.network));
    }
  }

  Uri _uri(String path, Map<String, String>? query) {
    final base = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(
      path: '$base$path',
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Result<T> _result<T>(
    http.Response response,
    T Function(Object? value) parse,
  ) {
    final envelope = _envelope(response);
    final codes = envelope == null ? const <String>[] : _codes(envelope);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return Success(parse(envelope?['value']));
      } on FormatException {
        return Failed(const ApiFailure(FailureKind.server));
      }
    }

    switch (response.statusCode) {
      case 401:
        if (codes.contains(invalidCredentialsCode)) {
          return Failed(ApiFailure(FailureKind.invalidCredentials, codes));
        }
        _onUnauthorized();
        return Failed(ApiFailure(FailureKind.unauthorized, codes));
      case 403:
        return Failed(ApiFailure(FailureKind.forbidden, codes));
      case 404:
        return Failed(ApiFailure(FailureKind.notFound, codes));
      case 429:
        return Failed(ApiFailure(FailureKind.tooManyAttempts, codes));
      case 400 || 409 || 422:
        return Failed(ApiFailure(FailureKind.rejected, codes));
      default:
        return Failed(ApiFailure(FailureKind.server, codes));
    }
  }

  Map<String, Object?>? _envelope(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  List<String> _codes(Map<String, Object?> envelope) {
    final errors = envelope['errors'];
    return errors is List<Object?>
        ? errors.whereType<String>().toList(growable: false)
        : const <String>[];
  }
}
