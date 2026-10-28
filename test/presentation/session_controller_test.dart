import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';

import '../support/fakes.dart';

void main() {
  group('restore', () {
    test('a saved session that is still valid signs the member in', () async {
      final store = FakeSessionStore(validSession());
      final controller = SessionController(store: store, now: () => testNow);

      await controller.restore();

      expect(controller.isRestoring, isFalse);
      expect(controller.session?.email, 'hilda@hotel.test');
      expect(controller.token, 'token-1');
    });

    test('an expired session is forgotten and shows the sign-in', () async {
      final store = FakeSessionStore(validSession());
      final controller = SessionController(
        store: store,
        now: () => testNow.add(const Duration(hours: 9)),
      );

      await controller.restore();

      expect(controller.session, isNull);
      expect(store.saved, isNull);
    });

    test('a session that expires exactly now is expired', () async {
      final store = FakeSessionStore(validSession());
      final controller = SessionController(
        store: store,
        now: () => testNow.add(const Duration(hours: 8)),
      );

      await controller.restore();

      expect(controller.session, isNull);
    });

    test('nothing saved shows the sign-in', () async {
      final controller = SessionController(
        store: FakeSessionStore(),
        now: () => testNow,
      );

      await controller.restore();

      expect(controller.isRestoring, isFalse);
      expect(controller.session, isNull);
    });
  });

  group('signIn and signOut', () {
    test(
      'signIn keeps the session in the store and tells the listeners',
      () async {
        final store = FakeSessionStore();
        final controller = SessionController(store: store, now: () => testNow);
        var notified = 0;
        controller.addListener(() => notified++);

        await controller.signIn(validSession(role: StaffRole.admin));

        expect(controller.session?.role, StaffRole.admin);
        expect(store.saved?.token, 'token-1');
        expect(notified, 1);
      },
    );

    test('signOut forgets the session at once and clears the store', () async {
      final store = FakeSessionStore(validSession());
      final controller = SessionController(store: store, now: () => testNow);
      await controller.restore();

      await controller.signOut();

      expect(controller.session, isNull);
      expect(controller.token, isNull);
      expect(store.saved, isNull);
    });

    test('a refused token ends the session', () async {
      final store = FakeSessionStore(validSession());
      final controller = SessionController(store: store, now: () => testNow);
      await controller.restore();

      controller.onUnauthorized();
      await Future<void>.value();

      expect(controller.session, isNull);
      expect(store.saved, isNull);
    });

    test('a refused token with nobody signed in changes nothing', () {
      final controller = SessionController(
        store: FakeSessionStore(),
        now: () => testNow,
      );
      var notified = 0;
      controller.addListener(() => notified++);

      controller.onUnauthorized();

      expect(notified, 0);
    });
  });
}
