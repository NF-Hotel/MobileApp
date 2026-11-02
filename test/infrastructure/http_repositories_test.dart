import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/room_service_note.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/http_auth_repository.dart';
import 'package:mobil_application/infrastructure/network/http_room_repository.dart';
import 'package:mobil_application/infrastructure/network/http_room_service_note_repository.dart';

/// The room as the API sends it: enums as numbers, camelCase names.
Map<String, Object?> roomJson({
  int id = 7,
  int housekeeping = 1,
  Map<String, Object?>? actions,
}) => {
  'roomId': id,
  'roomNumber': '207',
  'floor': 2,
  'size': 1,
  'capacity': 2,
  'status': 0,
  'housekeepingStatus': housekeeping,
  'isBookable': true,
  'hasBookings': false,
  'actions':
      actions ??
      {
        'canTakeOutOfService': true,
        'canSendToMaintenance': true,
        'canReturnToService': false,
        'canMarkDailyCleaningDue': false,
        'canMarkDepartureCleaningDue': false,
        'canStartCleaning': true,
        'canCompleteCleaning': false,
        'canReportServiceNeeded': true,
        'canStartService': false,
        'canCompleteService': false,
      },
};

/// The service note as the API sends it (`RoomServiceNoteDto`): the done fields
/// are null while the note is open.
Map<String, Object?> noteJson({
  String? doneBy,
  String? doneAt,
  String? undoableUntil,
}) => {
  'id': 12,
  'roomId': 7,
  'text': 'The tap drips',
  'writtenBy': 'hilda',
  'writtenAt': '2026-11-02T10:05:00+00:00',
  'doneBy': doneBy,
  'doneAt': doneAt,
  'undoableUntil': undoableUntil,
  'isDone': doneAt != null,
};

http.Response _ok(Object? value) => http.Response(
  jsonEncode({'value': value, 'errors': <String>[]}),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  late List<http.Request> sent;
  late ApiClient client;
  late http.Response Function(http.Request) answer;

  setUp(() {
    sent = <http.Request>[];
    answer = (_) => _ok(roomJson());
    client = ApiClient(
      httpClient: MockClient((request) async {
        sent.add(request);
        return answer(request);
      }),
      baseUri: Uri.parse('https://hotel.test/mobile-api'),
      tokenProvider: () => 'staff-token',
      onUnauthorized: () {},
    );
  });

  group('HttpAuthRepository', () {
    test(
      'signIn posts the user name and password and reads the session',
      () async {
        answer = (_) => _ok({
          'token': 'abc',
          'expiresAt': '2026-10-20T16:00:00+00:00',
          'userName': 'hilda',
          'role': 3,
        });

        final result = await HttpAuthRepository(client)
            .signIn('hilda', 'secret');

        final session = (result as Success<StaffSession>).value;
        expect(session.token, 'abc');
        expect(session.role, StaffRole.housekeeping);
        expect(session.expiresAt, DateTime.utc(2026, 10, 20, 16));
        expect(sent.single.url.path, '/mobile-api/api/auth/login');
        expect(jsonDecode(sent.single.body), {
          'userName': 'hilda',
          'password': 'secret',
        });
      },
    );

    test('every role number of the API is read', () async {
      for (final entry in {
        1: StaffRole.receptionist,
        2: StaffRole.manager,
        3: StaffRole.housekeeping,
      }.entries) {
        answer = (_) => _ok({
          'token': 't',
          'expiresAt': '2026-10-20T16:00:00Z',
          'userName': 'u',
          'role': entry.key,
        });

        final result = await HttpAuthRepository(client).signIn('u', 'p');

        expect((result as Success<StaffSession>).value.role, entry.value);
      }
    });
  });

  group('HttpRoomRepository', () {
    test(
      'readAll reads the rooms with their numbers, states and actions',
      () async {
        answer = (_) =>
            _ok([roomJson(id: 1), roomJson(id: 2, housekeeping: 4)]);

        final result = await HttpRoomRepository(client).readAll();

        final rooms = (result as Success<List<Room>>).value;
        expect(rooms.map((r) => r.roomId), [1, 2]);
        expect(rooms.first.roomNumber, '207');
        expect(rooms.first.size, RoomSize.double);
        expect(
          rooms.first.housekeepingStatus,
          HousekeepingStatus.dailyCleaningDue,
        );
        expect(
          rooms.last.housekeepingStatus,
          HousekeepingStatus.serviceRequired,
        );
        expect(rooms.first.actions.canStartCleaning, isTrue);
        expect(rooms.first.actions.canCompleteCleaning, isFalse);
        expect(sent.single.method, 'GET');
        expect(sent.single.url.path, '/mobile-api/api/rooms');
      },
    );

    test('read asks for the room by its key', () async {
      await HttpRoomRepository(client).read(7);

      expect(sent.single.url.path, '/mobile-api/api/rooms/7');
    });

    test('each action posts to its own path', () async {
      final paths = <RoomAction, String>{
        RoomAction.markDailyCleaningDue: 'mark-daily-cleaning-due',
        RoomAction.markDepartureCleaningDue: 'mark-departure-cleaning-due',
        RoomAction.startCleaning: 'start-cleaning',
        RoomAction.completeCleaning: 'complete-cleaning',
        RoomAction.reportServiceNeeded: 'report-service-needed',
        RoomAction.startService: 'start-service',
        RoomAction.completeService: 'complete-service',
      };
      for (final entry in paths.entries) {
        sent.clear();

        await HttpRoomRepository(client).perform(7, entry.key);

        expect(sent.single.method, 'POST', reason: entry.key.name);
        expect(sent.single.url.path, '/mobile-api/api/rooms/7/${entry.value}');
      }
    });

    test(
      'complete service says whether cleaning follows, other actions do not',
      () async {
        await HttpRoomRepository(client)
            .perform(7, RoomAction.completeService, requiresCleaning: true);
        await HttpRoomRepository(client).perform(7, RoomAction.startCleaning);

        expect(sent.first.url.queryParameters, {'requiresCleaning': 'true'});
        expect(sent.last.url.queryParameters, isEmpty);
      },
    );

    test('a room with an unknown state number is a server failure', () async {
      answer = (_) => _ok(roomJson(housekeeping: 99));

      final result = await HttpRoomRepository(client).read(7);

      expect((result as Failed<Room>).failure.kind, FailureKind.server);
    });

    test('the state may also come as a name', () async {
      final json = roomJson()..['housekeepingStatus'] = 'ServiceInProgress';
      answer = (_) => _ok(json);

      final result = await HttpRoomRepository(client).read(7);

      expect(
        (result as Success<Room>).value.housekeepingStatus,
        HousekeepingStatus.serviceInProgress,
      );
    });
  });

  group('HttpRoomServiceNoteRepository', () {
    late HttpRoomServiceNoteRepository notes;

    setUp(() {
      notes = HttpRoomServiceNoteRepository(client);
      answer = (_) => _ok(noteJson());
    });

    test('readCurrent reads an open note, with nothing about done', () async {
      answer = (_) => _ok([noteJson()]);

      final result = await notes.readCurrent();

      final note = (result as Success<List<RoomServiceNote>>).value.single;
      expect(note.id, 12);
      expect(note.roomId, 7);
      expect(note.text, 'The tap drips');
      expect(note.writtenBy, 'hilda');
      expect(note.writtenAt, DateTime.utc(2026, 11, 2, 10, 5));
      expect(note.isDone, isFalse);
      expect(note.doneBy, isNull);
      expect(note.undoableUntil, isNull);
      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/mobile-api/api/room-service-notes');
    });

    test('a done note says who, when and until when', () async {
      answer = (_) => _ok(
        noteJson(
          doneBy: 'tom',
          doneAt: '2026-11-02T10:10:00+00:00',
          undoableUntil: '2026-11-02T10:15:00+00:00',
        ),
      );

      final result = await notes.markDone(12);

      final note = (result as Success<RoomServiceNote>).value;
      expect(note.isDone, isTrue);
      expect(note.doneBy, 'tom');
      expect(note.doneAt, DateTime.utc(2026, 11, 2, 10, 10));
      expect(note.undoableUntil, DateTime.utc(2026, 11, 2, 10, 15));
    });

    test('readHistory asks for the room by its key', () async {
      answer = (_) => _ok(<Object?>[]);

      final result = await notes.readHistory(7);

      expect((result as Success<List<RoomServiceNote>>).value, isEmpty);
      expect(
        sent.single.url.path,
        '/mobile-api/api/room-service-notes/history/7',
      );
    });

    test('create posts the room and the text, and no name', () async {
      await notes.create(7, 'The tap drips');

      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/mobile-api/api/room-service-notes');
      expect(jsonDecode(sent.single.body), {
        'roomId': 7,
        'text': 'The tap drips',
      });
    });

    test('each change posts to its own path', () async {
      final calls = <String, Future<Object?> Function()>{
        'done': () => notes.markDone(12),
        'undo-done': () => notes.undoDone(12),
        'reopen': () => notes.reopen(12),
      };
      for (final entry in calls.entries) {
        sent.clear();

        await entry.value();

        expect(sent.single.method, 'POST', reason: entry.key);
        expect(
          sent.single.url.path,
          '/mobile-api/api/room-service-notes/12/${entry.key}',
        );
      }
    });

    test('an undo too late is a rejection with the code of the API', () async {
      answer = (_) => http.Response(
        jsonEncode({
          'value': null,
          'errors': ['room_service_note.undo_window_closed'],
        }),
        409,
      );

      final result = await notes.undoDone(12);

      final failure = (result as Failed<RoomServiceNote>).failure;
      expect(failure.kind, FailureKind.rejected);
      expect(failure.codes, ['room_service_note.undo_window_closed']);
    });

    test('a note that is not understood is a server failure', () async {
      answer = (_) => _ok(noteJson()..['writtenAt'] = 'yesterday');

      final result = await notes.markDone(12);

      expect(
        (result as Failed<RoomServiceNote>).failure.kind,
        FailureKind.server,
      );
    });
  });
}
