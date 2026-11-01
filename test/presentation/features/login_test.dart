import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/features/login/login_screen.dart';
import 'package:mobil_application/presentation/features/login/login_view_model.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

import '../../support/fakes.dart';

void main() {
  late FakeSessionStore store;
  late SessionController session;
  late FakeAuthRepository auth;
  late LoginViewModel viewModel;

  setUp(() {
    store = FakeSessionStore();
    session = SessionController(store: store, now: () => testNow);
    auth = FakeAuthRepository(Success(validSession()));
    viewModel = LoginViewModel(auth: auth, session: session);
  });

  group('LoginViewModel', () {
    test('a right sign-in keeps the session', () async {
      await viewModel.submit('  hilda ', 'secret');

      expect(session.session?.userName, 'hilda');
      expect(store.saved, isNotNull);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isBusy, isFalse);
      expect(auth.userNames, ['hilda'], reason: 'the user name is trimmed');
    });

    test(
      'a wrong password shows one message and keeps nobody signed in',
      () async {
        auth.result = const Failed(ApiFailure(FailureKind.invalidCredentials));

        await viewModel.submit('hilda', 'wrong');

        expect(
          viewModel.errorMessage,
          'The user name or the password is wrong.',
        );
        expect(session.session, isNull);
      },
    );

    test('too many attempts says to wait', () async {
      auth.result = const Failed(ApiFailure(FailureKind.tooManyAttempts));

      await viewModel.submit('hilda', 'wrong');

      expect(viewModel.errorMessage, contains('Too many failed attempts'));
    });

    test('a network failure says the system cannot be reached', () async {
      auth.result = const Failed(ApiFailure(FailureKind.network));

      await viewModel.submit('hilda', 'secret');

      expect(viewModel.errorMessage, contains('cannot be reached'));
    });

    test('an empty user name or password is not sent', () async {
      await viewModel.submit('   ', 'secret');
      await viewModel.submit('hilda', '');

      expect(auth.userNames, isEmpty);
      expect(viewModel.validateUserName(' '), Strings.userNameRequired);
      expect(viewModel.validatePassword(''), Strings.passwordRequired);
      expect(viewModel.validatePassword('x'), isNull);
    });
  });

  group('LoginScreen', () {
    Future<void> show(WidgetTester tester) =>
        tester.pumpWidget(MaterialApp(home: LoginScreen(viewModel: viewModel)));

    testWidgets('shows the two fields and the button', (tester) async {
      await show(tester);

      expect(find.byKey(const ValueKey('userName')), findsOneWidget);
      expect(find.byKey(const ValueKey('password')), findsOneWidget);
      expect(find.byKey(const ValueKey('signIn')), findsOneWidget);
    });

    testWidgets('hides the password as it is typed', (tester) async {
      await show(tester);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('password')),
          matching: find.byType(TextField),
        ),
      );

      expect(field.obscureText, isTrue);
    });

    testWidgets('empty fields show what is missing and call nothing', (
      tester,
    ) async {
      await show(tester);

      await tester.tap(find.byKey(const ValueKey('signIn')));
      await tester.pump();

      expect(find.text(Strings.userNameRequired), findsOneWidget);
      expect(find.text(Strings.passwordRequired), findsOneWidget);
      expect(auth.userNames, isEmpty);
    });

    testWidgets('a right sign-in calls the API with the typed values', (
      tester,
    ) async {
      await show(tester);

      await tester.enterText(find.byKey(const ValueKey('userName')), 'hilda');
      await tester.enterText(find.byKey(const ValueKey('password')), 'secret');
      await tester.tap(find.byKey(const ValueKey('signIn')));
      await tester.pumpAndSettle();

      expect(auth.userNames, ['hilda']);
      expect(session.session, isNotNull);
    });

    testWidgets('a refusal is shown under the fields', (tester) async {
      auth.result = const Failed(ApiFailure(FailureKind.invalidCredentials));
      await show(tester);

      await tester.enterText(find.byKey(const ValueKey('userName')), 'hilda');
      await tester.enterText(find.byKey(const ValueKey('password')), 'wrong');
      await tester.tap(find.byKey(const ValueKey('signIn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('loginError')), findsOneWidget);
      expect(
        find.text('The user name or the password is wrong.'),
        findsOneWidget,
      );
    });
  });
}
