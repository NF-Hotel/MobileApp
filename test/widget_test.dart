// The app as a whole: sign-in first, rooms after, and back to the sign-in when
// the session ends (MIL-029).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/app.dart';
import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';

import 'support/fakes.dart';

void main() {
  late FakeRoomRepository rooms;
  late FakeAuthRepository auth;

  setUp(() {
    rooms = FakeRoomRepository([
      room(
        id: 5,
        number: '305',
        floor: 3,
        housekeeping: HousekeepingStatus.departureCleaningDue,
        actions: const RoomActions(canStartCleaning: true),
      ),
    ]);
    auth = FakeAuthRepository(Success(validSession()));
  });

  Future<SessionController> start(
    WidgetTester tester,
    FakeSessionStore store,
  ) async {
    final session = SessionController(store: store, now: () => testNow);
    await tester.pumpWidget(
      NfHotelApp(session: session, auth: auth, rooms: rooms),
    );
    await session.restore();
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('with nobody signed in the sign-in is shown', (tester) async {
    await start(tester, FakeSessionStore());

    expect(find.byKey(const ValueKey('signIn')), findsOneWidget);
    expect(find.text('Rooms'), findsNothing);
  });

  testWidgets('a saved session goes straight to the rooms', (tester) async {
    await start(tester, FakeSessionStore(validSession()));

    expect(find.text('Rooms'), findsOneWidget);
    expect(find.byKey(const ValueKey('room-5')), findsOneWidget);
  });

  testWidgets('signing in shows the rooms from the API', (tester) async {
    await start(tester, FakeSessionStore());

    await tester.enterText(find.byKey(const ValueKey('userName')), 'hilda');
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret');
    await tester.tap(find.byKey(const ValueKey('signIn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('room-5')), findsOneWidget);
    expect(find.text('305'), findsOneWidget);
  });

  testWidgets('a session that ends on a room screen returns to the sign-in', (
    tester,
  ) async {
    final session = await start(tester, FakeSessionStore(validSession()));
    await tester.tap(find.byKey(const ValueKey('room-5')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('action-startCleaning')), findsOneWidget);

    session.onUnauthorized();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('signIn')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-startCleaning')), findsNothing);
  });

  testWidgets('signing out and in again reads the rooms again', (tester) async {
    await start(tester, FakeSessionStore(validSession()));
    await tester.tap(find.byKey(const ValueKey('signOut')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('signIn')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('userName')), 'hilda');
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret');
    await tester.tap(find.byKey(const ValueKey('signIn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('room-5')), findsOneWidget);
  });
}
