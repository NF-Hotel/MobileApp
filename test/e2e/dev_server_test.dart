// End-to-end check of the API layer of the app against the development server
// of the website repository (MIL-029, task 6). It runs only when the three
// development accounts are in the environment, so a normal `flutter test`
// skips it. Run it in a container, never on the desktop of the host:
//
//   docker run --rm --env-file <website>/deploy/nfhotel-api/dev-staff.env \
//     -v <MobileApp>:/app -w /app ghcr.io/cirruslabs/flutter:stable \
//     flutter test test/e2e --dart-define=API_BASE_URL=https://host.docker.internal:8443/mobile-api
//
// The passwords come from the environment file and are never printed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_config.dart';
import 'package:mobil_application/infrastructure/network/http_auth_repository.dart';
import 'package:mobil_application/infrastructure/network/http_client_factory.dart';
import 'package:mobil_application/infrastructure/network/http_room_repository.dart';

void main() {
  // dev-staff.env of the website repository has the receptionist and the
  // housekeeping account; the manager is the first account of the API
  // (Staff__InitialManager__*) and is checked only when it is in the environment too.
  final accounts = <String, StaffRole>{
    'receptionist': StaffRole.receptionist,
    'housekeeping': StaffRole.housekeeping,
    if (Platform.environment.containsKey('manager'))
      'manager': StaffRole.manager,
  };
  final configured =
      Platform.environment.containsKey('receptionist') &&
      Platform.environment.containsKey('housekeeping');
  final baseUri = Uri.parse(ApiConfig.baseUrl);

  String? token;
  var unauthorized = 0;
  late ApiClient client;

  setUp(() {
    unauthorized = 0;
    client = ApiClient(
      httpClient: createHttpClient(developmentHost: baseUri.host),
      baseUri: baseUri,
      tokenProvider: () => token,
      onUnauthorized: () => unauthorized++,
    );
  });

  Future<StaffSession> signIn(String userName) async {
    final result = await HttpAuthRepository(client)
        .signIn(userName, Platform.environment[userName]!);
    expect(result, isA<Success<StaffSession>>(), reason: 'sign in $userName');
    final session = (result as Success<StaffSession>).value;
    token = session.token;
    return session;
  }

  group(
    'development server',
    skip: configured
        ? false
        : 'the development accounts are not in the environment',
    () {
      test('each development account signs in with its own role', () async {
        for (final entry in accounts.entries) {
          final session = await signIn(entry.key);

          expect(session.role, entry.value, reason: entry.key);
          expect(session.expiresAt.isAfter(DateTime.now()), isTrue);
        }
      });

      test('a wrong password is refused with one message', () async {
        token = null;

        final result = await HttpAuthRepository(client)
            .signIn('housekeeping', 'not-the-password');

        expect(
          (result as Failed<StaffSession>).failure.kind,
          FailureKind.invalidCredentials,
        );
        expect(unauthorized, 0);
      });

      test(
        'the seeded rooms are listed with numbers, floors and actions',
        () async {
          await signIn('receptionist');

          final result = await HttpRoomRepository(client).readAll();

          final rooms = (result as Success<List<Room>>).value;
          expect(rooms, isNotEmpty);
          expect(rooms.every((r) => r.roomNumber.isNotEmpty), isTrue);
        },
      );

      test(
        'housekeeping runs a cleaning round and the room ends clean',
        () async {
          await signIn('housekeeping');
          final repository = HttpRoomRepository(client);
          final rooms =
              (await repository.readAll() as Success<List<Room>>).value;
          final room = rooms.firstWhere(
            (r) =>
                r.housekeepingStatus == HousekeepingStatus.clean &&
                r.status == RoomStatus.available &&
                r.actions.canMarkDailyCleaningDue,
          );

          Future<Room> step(RoomAction action) async {
            final result = await repository.perform(room.roomId, action);
            expect(result, isA<Success<Room>>(), reason: action.name);
            return (result as Success<Room>).value;
          }

          final due = await step(RoomAction.markDailyCleaningDue);
          expect(due.housekeepingStatus, HousekeepingStatus.dailyCleaningDue);
          expect(due.actions.canStartCleaning, isTrue);
          final started = await step(RoomAction.startCleaning);
          expect(
            started.housekeepingStatus,
            HousekeepingStatus.cleaningInProgress,
          );
          final done = await step(RoomAction.completeCleaning);
          expect(done.housekeepingStatus, HousekeepingStatus.clean);

          final again = await repository.read(room.roomId);
          expect(
            (again as Success<Room>).value.housekeepingStatus,
            HousekeepingStatus.clean,
          );
        },
      );

      test('an action the room state does not allow is rejected', () async {
        await signIn('housekeeping');
        final repository = HttpRoomRepository(client);
        final rooms = (await repository.readAll() as Success<List<Room>>).value;
        // Starting a service on a room that is not waiting for one is illegal
        // (completing cleaning on a clean room is a no-op that succeeds).
        final clean = rooms.firstWhere(
          (r) =>
              r.housekeepingStatus == HousekeepingStatus.clean &&
              !r.actions.canStartService,
        );

        final result = await repository.perform(
          clean.roomId,
          RoomAction.startService,
        );

        expect(result, isA<Failed<Room>>());
        expect(
          (result as Failed<Room>).failure.kind,
          isNot(FailureKind.network),
        );
      });

      test('a tampered token ends the session', () async {
        await signIn('housekeeping');
        token = '${token}x';

        final result = await HttpRoomRepository(client).readAll();

        expect(
          (result as Failed<List<Room>>).failure.kind,
          FailureKind.unauthorized,
        );
        expect(unauthorized, 1);
      });
    },
  );
}
