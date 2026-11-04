// The own account (MIL-059, ADR-0017): the change of a temporary password and
// the name of an account that has none, before the rooms; and the way to the
// change of the password and to the administration from the rooms.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/app.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

import '../../support/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeStaffRepository staff;

  setUp(() {
    auth = FakeAuthRepository(Success(validSession()));
    staff = FakeStaffRepository();
  });

  Future<SessionController> start(
    WidgetTester tester,
    StaffSession saved,
  ) async {
    final session = SessionController(
      store: FakeSessionStore(saved),
      now: () => testNow,
    );
    await tester.pumpWidget(
      NfHotelApp(
        session: session,
        auth: auth,
        rooms: FakeRoomRepository([room(id: 5, number: '305')]),
        serviceNotes: FakeRoomServiceNoteRepository(),
        staff: staff,
      ),
    );
    await session.restore();
    await tester.pumpAndSettle();
    return session;
  }

  Future<void> fillPasswords(
    WidgetTester tester,
    String current,
    String fresh,
    String again,
  ) async {
    await tester.enterText(
      find.byKey(const ValueKey('currentPassword')),
      current,
    );
    await tester.enterText(find.byKey(const ValueKey('newPassword')), fresh);
    await tester.enterText(
      find.byKey(const ValueKey('confirmPassword')),
      again,
    );
    await tester.tap(find.byKey(const ValueKey('savePassword')));
    await tester.pumpAndSettle();
  }

  group('a temporary password', () {
    testWidgets('must be changed before the rooms, then the rooms show', (
      tester,
    ) async {
      auth.changeResult = Success(
        validSession(firstName: 'Hilda', lastName: 'Berg', token: 'token-2'),
      );
      final session = await start(
        tester,
        validSession(mustChangePassword: true, firstName: 'H', lastName: 'B'),
      );

      expect(find.text(Strings.chooseNewPassword), findsOneWidget);
      expect(find.text(Strings.roomsTitle), findsNothing);

      await fillPasswords(
        tester,
        'temporary passphrase 7',
        'my own long passphrase',
        'my own long passphrase',
      );

      expect(auth.passwordChanges, [
        'temporary passphrase 7>my own long passphrase',
      ]);
      expect(session.token, 'token-2');
      expect(find.byKey(const ValueKey('room-5')), findsOneWidget);
    });

    testWidgets('is checked for length and for the repetition first', (
      tester,
    ) async {
      await start(tester, validSession(mustChangePassword: true));

      await fillPasswords(tester, 'old', 'short', 'other');

      expect(find.text(Strings.passwordTooShort), findsOneWidget);
      expect(find.text(Strings.passwordsDoNotMatch), findsOneWidget);
      expect(auth.passwordChanges, isEmpty);
    });

    testWidgets('a refusal shows the text of its code and stays', (
      tester,
    ) async {
      auth.changeResult = Failed(
        const ApiFailure(FailureKind.rejected, [
          'staff.current_password_invalid',
        ]),
      );
      await start(tester, validSession(mustChangePassword: true));

      await fillPasswords(
        tester,
        'wrong one at all',
        'my own long passphrase',
        'my own long passphrase',
      );

      expect(find.text('The current password is wrong.'), findsOneWidget);
      expect(find.text(Strings.chooseNewPassword), findsOneWidget);
    });

    testWidgets('can be left by signing out', (tester) async {
      final session = await start(
        tester,
        validSession(mustChangePassword: true),
      );

      await tester.tap(find.byKey(const ValueKey('signOut')));
      await tester.pumpAndSettle();

      expect(session.session, isNull);
      expect(find.byKey(const ValueKey('signIn')), findsOneWidget);
    });
  });

  group('an account without a name', () {
    testWidgets('is asked for it, and the rooms show with the name', (
      tester,
    ) async {
      auth.nameResult = Success(
        validSession(firstName: 'Hilda', lastName: 'Berg'),
      );
      await start(tester, validSession());

      expect(find.text(Strings.addYourName), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('firstName')),
        ' Hilda ',
      );
      await tester.enterText(find.byKey(const ValueKey('lastName')), 'Berg');
      await tester.tap(find.byKey(const ValueKey('saveName')));
      await tester.pumpAndSettle();

      expect(auth.names, ['Hilda Berg']);
      expect(find.text('Hilda Berg (Housekeeping)'), findsOneWidget);
    });

    testWidgets('empty names are refused before the API is asked', (
      tester,
    ) async {
      await start(tester, validSession());

      await tester.tap(find.byKey(const ValueKey('saveName')));
      await tester.pumpAndSettle();

      expect(find.text(Strings.firstNameRequired), findsOneWidget);
      expect(find.text(Strings.lastNameRequired), findsOneWidget);
      expect(auth.names, isEmpty);
    });

    testWidgets('goes on to the rooms when a Manager set the name meanwhile', (
      tester,
    ) async {
      auth.nameResult = Failed(
        const ApiFailure(FailureKind.rejected, ['staff.name_already_set']),
      );
      await start(tester, validSession());

      await tester.enterText(find.byKey(const ValueKey('firstName')), 'Hilda');
      await tester.enterText(find.byKey(const ValueKey('lastName')), 'Berg');
      await tester.tap(find.byKey(const ValueKey('saveName')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('room-5')), findsOneWidget);
    });
  });

  group('from the rooms', () {
    testWidgets('only a Manager sees the administration', (tester) async {
      await start(tester, validSession(firstName: 'Hilda', lastName: 'Berg'));
      expect(find.byKey(const ValueKey('administration')), findsNothing);

      await start(
        tester,
        validSession(
          role: StaffRole.manager,
          firstName: 'Mia',
          lastName: 'Holm',
        ),
      );
      expect(find.byKey(const ValueKey('administration')), findsOneWidget);
    });

    testWidgets('a Manager opens the administration with the accounts', (
      tester,
    ) async {
      staff.accounts = [
        staffAccount(id: 4, firstName: 'Rita', lastName: 'Hansen'),
      ];
      await start(
        tester,
        validSession(role: StaffRole.manager, firstName: 'M', lastName: 'H'),
      );

      await tester.tap(find.byKey(const ValueKey('administration')));
      await tester.pumpAndSettle();

      expect(find.text(Strings.createAccount), findsWidgets);
      expect(find.text('Rita Hansen'), findsOneWidget);
    });

    testWidgets('the password is changed and the page goes back', (
      tester,
    ) async {
      auth.changeResult = Success(
        validSession(firstName: 'Hilda', lastName: 'Berg', token: 'token-3'),
      );
      final session = await start(
        tester,
        validSession(firstName: 'Hilda', lastName: 'Berg'),
      );

      await tester.tap(find.byKey(const ValueKey('changePassword')));
      await tester.pumpAndSettle();
      await fillPasswords(
        tester,
        'correct horse battery',
        'my own long passphrase',
        'my own long passphrase',
      );

      expect(session.token, 'token-3');
      expect(find.text(Strings.passwordChanged), findsOneWidget);
      expect(find.byKey(const ValueKey('room-5')), findsOneWidget);
    });
  });

  group('SessionController', () {
    test(
      'asks for a name until it is skipped, and again after a sign-in',
      () async {
        final session = SessionController(store: FakeSessionStore());
        await session.signIn(validSession());
        expect(session.needsName, isTrue);

        session.skipNameSetup();
        expect(session.needsName, isFalse);

        await session.signIn(validSession());
        expect(session.needsName, isTrue);

        await session.signIn(
          validSession(firstName: 'Hilda', lastName: 'Berg'),
        );
        expect(session.needsName, isFalse);
      },
    );
  });
}
