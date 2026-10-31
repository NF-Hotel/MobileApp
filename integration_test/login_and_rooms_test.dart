// End-to-end test of the real screens against the development server of the
// website repository (MIL-029, issue 218). It runs the app's widgets with the
// real HTTP client and repositories, signs in as the development accounts and
// runs a cleaning round through the buttons.
//
// Run it in a container, never on the desktop of the host (AGENTS.md, "GUI
// testing"): see integration_test/run_in_docker.sh. The passwords come from the
// environment (--env-file) and are never printed. The session is kept in memory
// because a container has no keyring; the secure storage is checked on a device.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mobil_application/app.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/session_store.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_config.dart';
import 'package:mobil_application/infrastructure/network/http_auth_repository.dart';
import 'package:mobil_application/infrastructure/network/http_client_factory.dart';
import 'package:mobil_application/infrastructure/network/http_room_repository.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';

class _MemoryStore implements SessionStore {
  StaffSession? saved;

  @override
  Future<StaffSession?> read() async => saved;

  @override
  Future<void> save(StaffSession session) async => saved = session;

  @override
  Future<void> clear() async => saved = null;
}

/// Builds the app as `main` does, with the real client and repositories.
Future<SessionController> _start(WidgetTester tester) async {
  final baseUri = Uri.parse(ApiConfig.baseUrl);
  final session = SessionController(store: _MemoryStore());
  final client = ApiClient(
    httpClient: createHttpClient(developmentHost: baseUri.host),
    baseUri: baseUri,
    tokenProvider: () => session.token,
    onUnauthorized: session.onUnauthorized,
  );
  await tester.pumpWidget(
    NfHotelApp(
      session: session,
      auth: HttpAuthRepository(client),
      rooms: HttpRoomRepository(client),
    ),
  );
  await session.restore();
  await tester.pump();
  return session;
}

/// Pumps frames until [finder] matches, so that a real network call can end.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Did not find ${finder.toString()} in 30 seconds.');
}

Future<void> _signIn(WidgetTester tester, String user, String password) async {
  await tester.enterText(find.byKey(const ValueKey('userName')), user);
  await tester.enterText(find.byKey(const ValueKey('password')), password);
  await tester.tap(find.byKey(const ValueKey('signIn')));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final configured =
      env.containsKey('housekeeping') && env.containsKey('receptionist');

  group(
    'screens against the development server',
    skip: configured ? false : 'the development accounts are not set',
    () {
      testWidgets('a wrong password shows one message and stays on the sign-in', (
        tester,
      ) async {
        await _start(tester);

        await _signIn(tester, 'housekeeping', 'not-the-password');
        await _waitFor(tester, find.byKey(const ValueKey('loginError')));

        expect(
          find.text('The user name or the password is wrong.'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('signIn')), findsOneWidget);
      });

      testWidgets('housekeeping signs in, runs a cleaning round and signs out', (
        tester,
      ) async {
        await _start(tester);

        await _signIn(tester, 'housekeeping', env['housekeeping']!);
        await _waitFor(tester, find.byKey(const ValueKey('signedInAs')));
        expect(find.text('housekeeping (Housekeeping)'), findsOneWidget);
        final cleanTile = find.widgetWithText(Card, 'Clean').first;
        await _waitFor(tester, cleanTile);

        // Open a clean room and take it through a cleaning round with the buttons.
        await tester.tap(cleanTile);
        await _waitFor(
          tester,
          find.byKey(const ValueKey('action-markDailyCleaningDue')),
        );
        await tester.tap(find.byKey(const ValueKey('action-markDailyCleaningDue')));
        await _waitFor(tester, find.text('Daily cleaning due'));
        await tester.tap(find.byKey(const ValueKey('action-startCleaning')));
        await _waitFor(tester, find.text('Being cleaned'));
        await tester.tap(find.byKey(const ValueKey('action-completeCleaning')));
        await _waitFor(tester, find.text('Clean'));

        // Back on the overview, then out: the session ends and the sign-in shows.
        await tester.pageBack();
        await _waitFor(tester, find.byKey(const ValueKey('signOut')));
        await tester.tap(find.byKey(const ValueKey('signOut')));
        await _waitFor(tester, find.byKey(const ValueKey('signIn')));
        expect(find.byKey(const ValueKey('signedInAs')), findsNothing);
      });

      testWidgets('the receptionist signs in and sees the rooms', (tester) async {
        await _start(tester);

        await _signIn(tester, 'receptionist', env['receptionist']!);
        await _waitFor(tester, find.byKey(const ValueKey('signedInAs')));

        expect(find.text('receptionist (Receptionist)'), findsOneWidget);
        expect(find.byType(Card), findsWidgets);
      });
    },
  );
}
