import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobil_application/domain/entities/planning.dart';
import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/room_service_note.dart';
import 'package:mobil_application/domain/entities/staff_account.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/domain/repositories/planning_repository.dart';
import 'package:mobil_application/infrastructure/network/http_auth_repository.dart';
import 'package:mobil_application/infrastructure/network/http_planning_repository.dart';
import 'package:mobil_application/infrastructure/network/http_room_repository.dart';
import 'package:mobil_application/infrastructure/network/http_room_service_note_repository.dart';
import 'package:mobil_application/infrastructure/network/http_staff_repository.dart';

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

  group('the own account (MIL-059)', () {
    test('a session carries the must-change flag and the names', () async {
      answer = (_) => _ok({
        'token': 't',
        'expiresAt': '2026-10-20T16:00:00Z',
        'userName': 'hilda',
        'role': 3,
        'mustChangePassword': true,
        'firstName': 'Hilda',
        'lastName': 'Berg',
      });

      final result = await HttpAuthRepository(client).signIn('hilda', 'p');

      final session = (result as Success<StaffSession>).value;
      expect(session.mustChangePassword, isTrue);
      expect(session.displayName, 'Hilda Berg');
    });

    test('a session without the names has none', () async {
      answer = (_) => _ok({
        'token': 't',
        'expiresAt': '2026-10-20T16:00:00Z',
        'userName': 'hilda',
        'role': 3,
        'firstName': null,
      });

      final result = await HttpAuthRepository(client).signIn('hilda', 'p');

      final session = (result as Success<StaffSession>).value;
      expect(session.hasName, isFalse);
      expect(session.mustChangePassword, isFalse);
      expect(session.displayName, 'hilda');
    });

    test('the password and the name are posted below /api/staff/me', () async {
      answer = (_) => _ok({
        'token': 'new',
        'expiresAt': '2026-10-20T16:00:00Z',
        'userName': 'hilda',
        'role': 3,
      });
      final auth = HttpAuthRepository(client);

      await auth.changePassword('old secret', 'new secret');
      await auth.setOwnName('Hilda', 'Berg');

      expect(sent.map((request) => request.url.path), [
        '/mobile-api/api/staff/me/password',
        '/mobile-api/api/staff/me/name',
      ]);
      expect(jsonDecode(sent[0].body), {
        'currentPassword': 'old secret',
        'newPassword': 'new secret',
      });
      expect(jsonDecode(sent[1].body), {
        'firstName': 'Hilda',
        'lastName': 'Berg',
      });
    });
  });

  group('HttpPlanningRepository (MIL-060)', () {
    test('reads shifts in a period, with the times in UTC in the query', () async {
      answer = (_) => _ok([
        {
          'id': 1,
          'startsAt': '2026-11-10T06:00:00+00:00',
          'endsAt': '2026-11-10T14:00:00+00:00',
          'role': 3,
          'assigneeId': 7,
          'assigneeName': 'Hilda Berg',
        },
      ]);

      final result = await HttpPlanningRepository(
        client,
      ).readShifts(DateTime.utc(2026, 11, 9), DateTime.utc(2026, 11, 16));

      final shift = (result as Success<List<Shift>>).value.single;
      expect(shift.role, StaffRole.housekeeping);
      expect(shift.startsAt.toUtc(), DateTime.utc(2026, 11, 10, 6));
      expect(sent.single.url.path, '/mobile-api/api/shifts');
      expect(sent.single.url.queryParameters['from'], '2026-11-09T00:00:00.000Z');
    });

    test('reads a swap with both shifts and its state', () async {
      Map<String, Object?> shift(int id) => {
        'id': id,
        'startsAt': '2026-11-10T06:00:00Z',
        'endsAt': '2026-11-10T14:00:00Z',
        'role': 3,
        'assigneeId': id,
        'assigneeName': null,
      };
      answer = (_) => _ok([
        {
          'id': 4,
          'shift': shift(1),
          'swapShift': shift(2),
          'offeredById': 1,
          'offeredByName': 'Hilda Berg',
          'takenById': 2,
          'takenByName': 'Otto Lund',
          'state': 2,
          'isClosed': false,
          'offeredAt': '2026-11-01T10:00:00Z',
        },
      ]);

      final result = await HttpPlanningRepository(client).readShiftTrades();

      final trade = (result as Success<List<ShiftTrade>>).value.single;
      expect(trade.isSwap, isTrue);
      expect(trade.state, TradeState.awaitingApproval);
      expect(trade.takenByName, 'Otto Lund');
    });

    test('every step and change goes to its route with its verb', () async {
      final shift = {
        'id': 1,
        'startsAt': '2026-11-10T06:00:00Z',
        'endsAt': '2026-11-10T14:00:00Z',
        'role': 3,
      };
      final trade = {
        'id': 4,
        'shift': shift,
        'offeredById': 1,
        'offeredByName': 'H',
        'state': 1,
        'isClosed': false,
      };
      final roomTrade = {
        'id': 5,
        'fromStaffId': 1,
        'fromName': 'H',
        'toStaffId': 2,
        'toName': 'O',
        'give': [
          {'roomId': 101, 'roomNumber': '101'},
        ],
        'take': <Object?>[],
        'state': 1,
      };
      answer = (request) => _ok(
        request.url.path.contains('room-trades')
            ? roomTrade
            : request.url.path.contains('shift-trades')
            ? trade
            : request.method == 'DELETE' || request.url.path.contains('assignments')
            ? null
            : shift,
      );
      final repository = HttpPlanningRepository(client);

      await repository.createShift(
        DateTime.utc(2026, 11, 10, 6),
        DateTime.utc(2026, 11, 10, 14),
        StaffRole.housekeeping,
        7,
      );
      await repository.updateShift(
        1,
        DateTime.utc(2026, 11, 10, 6),
        DateTime.utc(2026, 11, 10, 14),
        StaffRole.housekeeping,
        null,
      );
      await repository.deleteShift(1);
      await repository.offerShift(1, swapShiftId: 2);
      await repository.stepShiftTrade(4, TradeStep.take);
      await repository.assignRoom(101, 7);
      await repository.offerRooms(2, [101], [201]);
      await repository.stepRoomTrade(5, TradeStep.approve);

      expect(sent.map((request) => '${request.method} ${request.url.path}'), [
        'POST /mobile-api/api/shifts',
        'PUT /mobile-api/api/shifts/1',
        'DELETE /mobile-api/api/shifts/1',
        'POST /mobile-api/api/shift-trades',
        'POST /mobile-api/api/shift-trades/4/take',
        'PUT /mobile-api/api/room-assignments/101',
        'POST /mobile-api/api/room-trades',
        'POST /mobile-api/api/room-trades/5/approve',
      ]);
      expect(jsonDecode(sent[0].body), {
        'startsAt': '2026-11-10T06:00:00.000Z',
        'endsAt': '2026-11-10T14:00:00.000Z',
        'role': 3,
        'assigneeId': 7,
      });
      expect(jsonDecode(sent[3].body), {'shiftId': 1, 'swapShiftId': 2});
      expect(jsonDecode(sent[5].body), {'staffId': 7});
      expect(jsonDecode(sent[6].body), {
        'toStaffId': 2,
        'giveRoomIds': [101],
        'takeRoomIds': [201],
      });
    });

    test('reads the rooms with their housekeepers', () async {
      answer = (_) => _ok({
        'rooms': [
          {'roomId': 101, 'roomNumber': '101', 'floor': 1, 'staffId': 7, 'staffName': 'Hilda Berg'},
          {'roomId': 102, 'roomNumber': '102', 'floor': 1, 'staffId': null, 'staffName': null},
        ],
        'housekeepers': [
          {'id': 7, 'name': 'Hilda Berg', 'roomCount': 1},
        ],
        'minimumRooms': 3,
      });

      final result = await HttpPlanningRepository(client).readRoomAssignments();

      final overview = (result as Success<RoomAssignmentOverview>).value;
      expect(overview.roomsOf(7).single.roomNumber, '101');
      expect(overview.minimumRooms, 3);
    });

    test('the session carries the key of the account', () async {
      answer = (_) => _ok({
        'token': 't',
        'expiresAt': '2026-10-20T16:00:00Z',
        'userName': 'hilda',
        'role': 3,
        'staffId': 7,
      });

      final result = await HttpAuthRepository(client).signIn('hilda', 'p');

      expect((result as Success<StaffSession>).value.staffId, 7);
    });
  });

  group('HttpStaffRepository', () {
    test('readAll reads the accounts with their names and roles', () async {
      answer = (_) => _ok([
        {
          'id': 4,
          'userName': 'rita',
          'role': 2,
          'isActive': true,
          'mustChangePassword': false,
          'firstName': 'Rita',
          'lastName': 'Hansen',
          'email': 'rita@hotel.dk',
        },
        {
          'id': 7,
          'userName': 'otto',
          'role': 3,
          'isActive': false,
          'mustChangePassword': true,
        },
      ]);

      final result = await HttpStaffRepository(client).readAll();

      final accounts = (result as Success<List<StaffAccount>>).value;
      expect(accounts.first.role, StaffRole.manager);
      expect(accounts.first.displayName, 'Rita Hansen');
      expect(accounts.first.email, 'rita@hotel.dk');
      expect(accounts.last.isActive, isFalse);
      expect(accounts.last.displayName, 'otto');
      expect(sent.single.url.path, '/mobile-api/api/staff');
      expect(sent.single.headers['X-Staff-Token'], 'staff-token');
    });

    test('create posts the fields with the role as its number', () async {
      answer = (_) => _ok(null);

      final result = await HttpStaffRepository(client).create(
        const NewStaffAccount(
          firstName: 'Lena',
          lastName: 'Berg',
          userName: 'lena',
          temporaryPassword: 'temporary passphrase 7',
          role: StaffRole.housekeeping,
        ),
      );

      expect(result, isA<Success<void>>());
      expect(sent.single.method, 'POST');
      expect(jsonDecode(sent.single.body), {
        'userName': 'lena',
        'password': 'temporary passphrase 7',
        'role': 3,
        'firstName': 'Lena',
        'lastName': 'Berg',
        'email': null,
      });
    });

    test('every change goes to its route with its verb', () async {
      answer = (_) => _ok(null);
      final repository = HttpStaffRepository(client);

      await repository.rename(4, 'Rita', 'Holm');
      await repository.changeEmail(4, null);
      await repository.changeRole(4, StaffRole.receptionist);
      await repository.resetPassword(4, 'temporary passphrase 7');
      await repository.disable(4);
      await repository.enable(4);
      await repository.delete(4);

      expect(sent.map((request) => '${request.method} ${request.url.path}'), [
        'POST /mobile-api/api/staff/4/name',
        'POST /mobile-api/api/staff/4/email',
        'POST /mobile-api/api/staff/4/role',
        'POST /mobile-api/api/staff/4/password',
        'POST /mobile-api/api/staff/4/disable',
        'POST /mobile-api/api/staff/4/enable',
        'DELETE /mobile-api/api/staff/4',
      ]);
      expect(jsonDecode(sent[1].body), {'email': null});
      expect(jsonDecode(sent[2].body), {'role': 1});
      expect(jsonDecode(sent[3].body), {
        'newPassword': 'temporary passphrase 7',
      });
    });

    test('a conflict keeps its code', () async {
      answer = (_) => http.Response(
        jsonEncode({
          'errors': ['staff.cannot_delete_self'],
        }),
        409,
      );

      final result = await HttpStaffRepository(client).delete(1);

      final failure = (result as Failed<void>).failure;
      expect(failure.kind, FailureKind.rejected);
      expect(failure.codes, ['staff.cannot_delete_self']);
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
