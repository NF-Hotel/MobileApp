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
      baseUri: Uri.parse('https://hotel.test:8443/mobile-api'),
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
    test('get sends the staff token and no Authorization header', () async {
      token = 'staff-token';
      final client = clientAnswering(
        (_) => _json(200, {'value': 7, 'errors': <String>[]}),
      );

      await client.get('/api/rooms', (v) => v);

      expect(sent.single.headers[ApiClient.staffTokenHeader], 'staff-token');
      expect(sent.single.headers.containsKey('authorization'), isFalse);
    });

    test('get sends no staff token header when nobody is signed in', () async {
      final client = clientAnswering(
        (_) => _json(200, {'value': 1, 'errors': <String>[]}),
      );

      await client.get('/api/rooms', (v) => v);

      expect(sent.single.headers.containsKey('x-staff-token'), isFalse);
    });

    test('the path is put after the path of the base address', () async {
      final client = clientAnswering(
        (_) => _json(200, {'value': 1, 'errors': <String>[]}),
      );

      await client.get('/api/rooms/5', (v) => v);

      expect(
        sent.single.url.toString(),
        'https://hotel.test:8443/mobile-api/api/rooms/5',
      );
    });

    test('post sends the body as JSON and the query', () async {
      final client = clientAnswering(
        (_) => _json(200, {'value': 1, 'errors': <String>[]}),
      );

      await client.post(
        '/api/x',
        (v) => v,
        body: {'userName': 'a'},
        query: {'requiresCleaning': 'true'},
      );

      expect(sent.single.method, 'POST');
      expect(sent.single.url.query, 'requiresCleaning=true');
      expect(sent.single.headers['content-type'], contains('application/json'));
      expect(jsonDecode(sent.single.body), {'userName': 'a'});
    });
  });

  group('result', () {
    test('a 200 gives the parsed value', () async {
      final client = clientAnswering(
        (_) => _json(200, {'value': 42, 'errors': <String>[]}),
      );

      final result = await client.get<int>('/p', (v) => v! as int);

      expect((result as Success<int>).value, 42);
    });

    test('a value of the wrong shape is a server failure', () async {
      final client = clientAnswering(
        (_) => _json(200, {'value': 'text', 'errors': <String>[]}),
      );

      final result = await client.get<int>(
        '/p',
        (v) => throw const FormatException('bad'),
      );

      expect((result as Failed<int>).failure.kind, FailureKind.server);
    });

    test('a 401 with the credentials code is not an ended session', () async {
      final client = clientAnswering(
        (_) => _json(401, {
          'errors': ['staff.invalid_credentials'],
        }),
      );

      final result = await client.post<int>('/api/auth/login', (v) => 1);

      expect(
        (result as Failed<int>).failure.kind,
        FailureKind.invalidCredentials,
      );
      expect(unauthorized, 0);
    });

    test('any other 401 ends the session', () async {
      final client = clientAnswering(
        (_) => _json(401, {
          'errors': ['api.staff_unauthorized'],
        }),
      );

      final result = await client.get<int>('/api/rooms', (v) => 1);

      expect((result as Failed<int>).failure.kind, FailureKind.unauthorized);
      expect(unauthorized, 1);
    });

    test('each other status maps to its kind and keeps the codes', () async {
      final cases = <int, FailureKind>{
        403: FailureKind.forbidden,
        404: FailureKind.notFound,
        429: FailureKind.tooManyAttempts,
        400: FailureKind.rejected,
        409: FailureKind.rejected,
        500: FailureKind.server,
        503: FailureKind.server,
      };
      for (final entry in cases.entries) {
        final client = clientAnswering(
          (_) => _json(entry.key, {
            'errors': ['some.code'],
          }),
        );

        final result = await client.get<int>('/p', (v) => 1);

        final failure = (result as Failed<int>).failure;
        expect(failure.kind, entry.value, reason: 'status ${entry.key}');
        expect(failure.codes, ['some.code']);
      }
      expect(unauthorized, 0);
    });

    test(
      'an answer that is not JSON is a server failure, not a crash',
      () async {
        final client = clientAnswering((_) => http.Response('<html>', 502));

        final result = await client.get<int>('/p', (v) => 1);

        expect((result as Failed<int>).failure.kind, FailureKind.server);
      },
    );

    test('a client error is a network failure', () async {
      final client = clientAnswering((_) => throw http.ClientException('down'));

      final result = await client.get<int>('/p', (v) => 1);

      expect((result as Failed<int>).failure.kind, FailureKind.network);
    });

    test('a call that takes too long is a network failure', () async {
      final client = clientAnswering(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      );

      final result = await client.get<int>('/p', (v) => 1);

      expect((result as Failed<int>).failure.kind, FailureKind.network);
    });
  });
}
