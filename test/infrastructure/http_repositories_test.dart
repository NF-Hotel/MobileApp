import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_json.dart';
import 'package:mobil_application/infrastructure/network/http_auth_repository.dart';
import 'package:mobil_application/infrastructure/network/http_room_repository.dart';

import '../support/fakes.dart';

const _roleClaim =
    'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

/// The claims `CreateToken` of the API writes.
Map<String, Object?> claims({
  String role = 'cleaner',
  String givenName = 'Hilda',
  String familyName = 'Berg',
}) => {
  'sub': '7',
  'email': 'hilda@hotel.test',
  'given_name': givenName,
  'family_name': familyName,
  _roleClaim: role,
  'exp': DateTime.utc(2026, 10, 20, 16).millisecondsSinceEpoch ~/ 1000,
};

void main() {
  late List<http.Request> sent;
  late http.Response Function(http.Request request) answer;
  late ApiClient client;

  http.Response ok([Object? body]) => http.Response(
    body == null ? '' : jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    sent = <http.Request>[];
    answer = (_) => ok();
    client = ApiClient(
      httpClient: MockClient((request) async {
        sent.add(request);
        return answer(request);
      }),
      baseUri: Uri.parse('http://hotel.test:5142'),
      tokenProvider: () => null,
      onUnauthorized: () {},
    );
  });

  group('HttpAuthRepository', () {
    test('signIn posts the email and password and reads the token', () async {
      final token = jwt(claims());
      answer = (_) => ok({'accessToken': token});

      final result = await HttpAuthRepository(
        client,
      ).signIn('hilda@hotel.test', 'secret');

      final session = (result as Success<StaffSession>).value;
      expect(session.token, token);
      expect(session.email, 'hilda@hotel.test');
      expect(session.displayName, 'Hilda Berg');
      expect(session.role, StaffRole.cleaner);
      expect(session.expiresAt, DateTime.utc(2026, 10, 20, 16));
      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/auth/login');
      expect(jsonDecode(sent.single.body), {
        'email': 'hilda@hotel.test',
        'password': 'secret',
      });
    });

    test('setName puts the name and reads the new token', () async {
      answer = (_) => ok({'accessToken': jwt(claims(givenName: 'Ida'))});

      final result = await HttpAuthRepository(client).setName('Ida', 'Berg');

      expect((result as Success<StaffSession>).value.firstName, 'Ida');
      expect(sent.single.method, 'PUT');
      expect(sent.single.url.path, '/me/name');
      expect(jsonDecode(sent.single.body), {
        'firstName': 'Ida',
        'lastName': 'Berg',
      });
    });
  });

  group('ApiJson.sessionFromToken', () {
    test('every role of the API is read', () {
      for (final role in StaffRole.values) {
        final session = ApiJson.sessionFromToken(jwt(claims(role: role.name)));
        expect(session.role, role);
        expect(session.isAdmin, role == StaffRole.admin);
      }
    });

    test('the short "role" claim is read too', () {
      final short = {...claims()}
        ..remove(_roleClaim)
        ..['role'] = 'admin';

      expect(ApiJson.sessionFromToken(jwt(short)).role, StaffRole.admin);
    });

    test('an account without a name shows its email', () {
      final session = ApiJson.sessionFromToken(
        jwt(claims(givenName: '', familyName: '')),
      );

      expect(session.hasName, isFalse);
      expect(session.displayName, 'hilda@hotel.test');
    });

    test('a token that is not a JWT, or an unknown role, is refused', () {
      expect(() => ApiJson.sessionFromToken('abc'), throwsFormatException);
      expect(
        () => ApiJson.sessionFromToken(jwt(claims(role: 'guest'))),
        throwsFormatException,
      );
    });
  });

  group('HttpRoomRepository', () {
    test('readAll reads the rooms with their state and cleaners', () async {
      answer = (_) => ok([
        {
          'number': 1,
          'name': 'Suite 1',
          'status': 'needsCleaning',
          'cleaners': ['Hilda Berg', 'ole@hotel.test'],
        },
        {'number': 2, 'name': '102', 'status': 'clean', 'cleaners': []},
      ]);

      final result = await HttpRoomRepository(client).readAll();

      final rooms = (result as Success<List<Room>>).value;
      expect(rooms.map((r) => r.number), [1, 2]);
      expect(rooms.first.name, 'Suite 1');
      expect(rooms.first.status, RoomStatus.needsCleaning);
      expect(rooms.first.cleaners, ['Hilda Berg', 'ole@hotel.test']);
      expect(rooms.last.cleaners, isEmpty);
      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/rooms');
    });

    test('an unknown status is a server failure', () async {
      answer = (_) => ok([
        {'number': 1, 'name': '101', 'status': 'onFire', 'cleaners': []},
      ]);

      final result = await HttpRoomRepository(client).readAll();

      expect((result as Failed).failure.kind, FailureKind.server);
    });

    test('setStatus puts the name of the status', () async {
      await HttpRoomRepository(
        client,
      ).setStatus(4, RoomStatus.needsMaintenance);

      expect(sent.single.method, 'PUT');
      expect(sent.single.url.path, '/rooms/4/status');
      expect(jsonDecode(sent.single.body), {'status': 'needsMaintenance'});
    });

    test('readNotes reads the notes with who and when', () async {
      answer = (_) => ok([
        {
          'id': 9,
          'body': 'Lamp is broken',
          'createdBy': 'hilda@hotel.test',
          'createdAt': '2026-10-20T08:00:00Z',
          'resolvedBy': 'ole@hotel.test',
          'resolvedAt': '2026-10-20T09:30:00Z',
        },
        {
          'id': 8,
          'body': 'Towels',
          'createdBy': 'ole@hotel.test',
          'createdAt': '2026-10-19T08:00:00Z',
          'resolvedBy': null,
          'resolvedAt': null,
        },
      ]);

      final result = await HttpRoomRepository(client).readNotes(4);

      final notes = (result as Success<List<RoomNote>>).value;
      expect(notes.first.id, 9);
      expect(notes.first.createdAt, DateTime.utc(2026, 10, 20, 8));
      expect(notes.first.isResolved, isTrue);
      expect(notes.first.resolvedBy, 'ole@hotel.test');
      expect(notes.last.isResolved, isFalse);
      expect(sent.single.url.path, '/rooms/4/notes');
    });

    test('the changes to notes use the routes of the API', () async {
      final rooms = HttpRoomRepository(client);

      await rooms.addNote(4, 'Towels');
      await rooms.setResolved(4, 9, true);
      await rooms.deleteNote(4, 9);

      expect(sent.map((r) => '${r.method} ${r.url.path}'), [
        'POST /rooms/4/notes',
        'PUT /rooms/4/notes/9/resolved',
        'DELETE /rooms/4/notes/9',
      ]);
      expect(jsonDecode(sent[0].body), {'body': 'Towels'});
      expect(jsonDecode(sent[1].body), {'resolved': true});
    });
  });
}
