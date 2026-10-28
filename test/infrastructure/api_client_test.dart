import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late List<http.Request> sent;
  late int unauthorized;
  String? token;

  ApiClient clientAnswering(
    FutureOr<http.Response> Function(http.Request request) answer, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return ApiClient(
      httpClient: MockClient((request) async {
        sent.add(request);
        return answer(request);
      }),
      baseUri: Uri.parse('http://hotel.test:5142'),
      tokenProvider: () => token,
      onUnauthorized: () => unauthorized++,
      timeout: timeout,
    );
  }

  setUp(() {
    sent = <http.Request>[];
    unauthorized = 0;
    token = null;
  });

  group('request', () {
    test('a signed-in call sends the token as a bearer token', () async {
      token = 'jwt-1';
      final client = clientAnswering((_) => _json(200, 7));

      await client.get('/rooms', (v) => v);

      expect(sent.single.headers['Authorization'], 'Bearer jwt-1');
    });

    test('a call with nobody signed in sends no Authorization', () async {
      final client = clientAnswering((_) => _json(200, 1));

      await client.get('/rooms', (v) => v);

      expect(sent.single.headers.containsKey('Authorization'), isFalse);
    });

    test('the path is put after the path of the base address', () async {
      final client = ApiClient(
        httpClient: MockClient((request) async {
          sent.add(request);
          return _json(200, 1);
        }),
        baseUri: Uri.parse('https://hotel.test/api/'),
        tokenProvider: () => null,
        onUnauthorized: () {},
      );

      await client.get('/rooms', (v) => v);

      expect(sent.single.url.toString(), 'https://hotel.test/api/rooms');
    });

    test('send uses the method and the body as JSON', () async {
      final client = clientAnswering((_) => http.Response('', 200));

      await client.send('PUT', '/rooms/3/status', body: {'status': 'clean'});

      expect(sent.single.method, 'PUT');
      expect(sent.single.url.path, '/rooms/3/status');
      expect(
        sent.single.headers['Content-Type'],
        startsWith('application/json'),
      );
      expect(jsonDecode(sent.single.body), {'status': 'clean'});
    });

    test('a call without a body sends none', () async {
      final client = clientAnswering((_) => http.Response('', 200));

      await client.send<void>('DELETE', '/rooms/3/notes/9');

      expect(sent.single.body, isEmpty);
      expect(sent.single.headers.containsKey('Content-Type'), isFalse);
    });
  });

  group('response', () {
    test('the JSON body is parsed', () async {
      final client = clientAnswering(
        (_) => _json(200, [
          {'number': 1},
        ]),
      );

      final result = await client.get('/rooms', (v) => (v! as List).length);

      expect((result as Success<int>).value, 1);
    });

    test('an empty 200 is a success with no value', () async {
      final client = clientAnswering((_) => http.Response('', 200));

      final result = await client.send<void>('POST', '/rooms/1/notes');

      expect(result, isA<Success<void>>());
    });

    test('a body that is not understood is a server failure', () async {
      final client = clientAnswering((_) => http.Response('<html>', 200));

      final result = await client.get('/rooms', (v) => v);

      expect((result as Failed).failure.kind, FailureKind.server);
    });

    test('a parse error is a server failure', () async {
      final client = clientAnswering((_) => _json(200, 'x'));

      final result = await client.get<int>(
        '/rooms',
        (_) => throw const FormatException('no'),
      );

      expect((result as Failed).failure.kind, FailureKind.server);
    });

    test('every status turns into its kind', () async {
      token = 'jwt-1';
      for (final entry in {
        403: FailureKind.forbidden,
        404: FailureKind.notFound,
        400: FailureKind.rejected,
        409: FailureKind.rejected,
        500: FailureKind.server,
        503: FailureKind.server,
      }.entries) {
        final client = clientAnswering(
          (_) => _json(entry.key, 'Name already set'),
        );

        final result = await client.get('/rooms', (v) => v);

        expect(
          (result as Failed).failure.kind,
          entry.value,
          reason: '${entry.key}',
        );
      }
      expect(unauthorized, 0);
    });

    test('a 401 with a token ends the session', () async {
      token = 'jwt-1';
      final client = clientAnswering((_) => http.Response('', 401));

      final result = await client.get('/rooms', (v) => v);

      expect((result as Failed).failure.kind, FailureKind.unauthorized);
      expect(unauthorized, 1);
    });

    test('a 401 without a token is a wrong email or password', () async {
      final client = clientAnswering((_) => http.Response('', 401));

      final result = await client.send('POST', '/auth/login', body: {});

      expect((result as Failed).failure.kind, FailureKind.invalidCredentials);
      expect(unauthorized, 0);
    });
  });

  group('network', () {
    test('a connection error is a network failure', () async {
      final client = clientAnswering(
        (_) => throw http.ClientException('refused'),
      );

      final result = await client.get('/rooms', (v) => v);

      expect((result as Failed).failure.kind, FailureKind.network);
    });

    test('no answer in time is a network failure', () async {
      final client = clientAnswering(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 10),
      );

      final result = await client.get('/rooms', (v) => v);

      expect((result as Failed).failure.kind, FailureKind.network);
    });
  });
}
