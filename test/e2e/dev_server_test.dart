// End-to-end check of the API layer of the app against a running LoginApi
// (`cd api && dotnet run`). It runs only when an account is in
// the environment, so a normal `flutter test` skips it:
//
//   NFHOTEL_EMAIL=... NFHOTEL_PASSWORD=... flutter test test/e2e \
//     --dart-define=API_BASE_URL=http://localhost:5142
//
// It changes nothing in the database: the status it sets is the one the room
// already has. The password is never printed.

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
  final email = Platform.environment['NFHOTEL_EMAIL'];
  final password = Platform.environment['NFHOTEL_PASSWORD'];
  final baseUri = Uri.parse(ApiConfig.baseUrl);

  String? token;
  var unauthorized = 0;
  late ApiClient client;

  setUp(() {
    token = null;
    unauthorized = 0;
    client = ApiClient(
      httpClient: createHttpClient(developmentHost: baseUri.host),
      baseUri: baseUri,
      tokenProvider: () => token,
      onUnauthorized: () => unauthorized++,
    );
  });

  Future<StaffSession> signIn() async {
    final result = await HttpAuthRepository(client).signIn(email!, password!);
    expect(result, isA<Success<StaffSession>>(), reason: 'sign in $email');
    final session = (result as Success<StaffSession>).value;
    token = session.token;
    return session;
  }

  group(
    'LoginApi',
    skip: email != null && password != null
        ? false
        : 'NFHOTEL_EMAIL and NFHOTEL_PASSWORD are not in the environment',
    () {
      test('the account signs in and its token is read', () async {
        final session = await signIn();

        expect(session.email, email);
        expect(session.expiresAt.isAfter(DateTime.now()), isTrue);
      });

      test('a wrong password is refused with one message', () async {
        final result = await HttpAuthRepository(
          client,
        ).signIn(email!, 'not-the-password');

        expect(
          (result as Failed<StaffSession>).failure.kind,
          FailureKind.invalidCredentials,
        );
        expect(unauthorized, 0);
      });

      test('the rooms, their notes and their status are reachable', () async {
        await signIn();
        final repository = HttpRoomRepository(client);

        final rooms = await repository.readAll();
        expect(rooms, isA<Success<List<Room>>>());
        final list = (rooms as Success<List<Room>>).value;
        if (list.isEmpty) {
          markTestSkipped('the account sees no rooms');
          return;
        }

        final room = list.first;
        expect(
          await repository.readNotes(room.number),
          isA<Success<List<RoomNote>>>(),
        );
        expect(
          await repository.setStatus(room.number, room.status),
          isA<Success<void>>(),
        );
      });

      test('a tampered token ends the session', () async {
        await signIn();
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
