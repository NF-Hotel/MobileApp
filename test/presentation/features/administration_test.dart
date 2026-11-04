// The administration of a Manager (MIL-059): the list of accounts, a new
// account, and the changes of one through its menu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/entities/staff_account.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/features/administration/administration_screen.dart';
import 'package:mobil_application/presentation/features/administration/administration_view_model.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

import '../../support/fakes.dart';

void main() {
  late FakeStaffRepository staff;

  setUp(() {
    staff = FakeStaffRepository([
      staffAccount(
        id: 1,
        userName: 'mia',
        role: StaffRole.manager,
        firstName: 'Mia',
        lastName: 'Holm',
      ),
      staffAccount(
        id: 4,
        firstName: 'Rita',
        lastName: 'Hansen',
        email: 'rita@hotel.dk',
      ),
      staffAccount(id: 7, userName: 'otto', isActive: false),
    ]);
  });

  AdministrationViewModel viewModel() =>
      AdministrationViewModel(staff: staff, ownUserName: 'mia');

  group('AdministrationViewModel', () {
    test('reads the accounts and knows the own one', () async {
      final model = viewModel();

      await model.load();

      expect(model.state, AdministrationState.ready);
      expect(model.accounts, hasLength(3));
      expect(model.isOwn(model.accounts.first), isTrue);
      expect(model.isOwn(model.accounts[1]), isFalse);
    });

    test('a change gives its receipt and reads the list again', () async {
      final model = viewModel();
      await model.load();

      final outcome = await model.create(
        const NewStaffAccount(
          firstName: 'Lena',
          lastName: 'Berg',
          userName: 'Lena',
          temporaryPassword: 'temporary passphrase 7',
          role: StaffRole.housekeeping,
        ),
      );

      expect(outcome.saved, isTrue);
      expect(outcome.message, Strings.accountCreated('lena'));
      expect(
        model.accounts.map((account) => account.userName),
        contains('Lena'),
      );
      expect(model.isBusy, isFalse);
    });

    test('a refusal gives the text of its code', () async {
      staff.changeFailure = const ApiFailure(FailureKind.rejected, [
        'staff.last_manager',
      ]);
      final model = viewModel();
      await model.load();

      final outcome = await model.changeRole(
        model.accounts.first,
        StaffRole.receptionist,
      );

      expect(outcome.saved, isFalse);
      expect(outcome.message, contains('At least one active Manager'));
    });

    test('an empty address is sent as none', () async {
      final model = viewModel();
      await model.load();

      await model.changeEmail(model.accounts[1], '  ');

      expect(staff.calls, ['email:4:null']);
    });

    test('a list that cannot be read is an error with its text', () async {
      staff.readFailure = const ApiFailure(FailureKind.forbidden);
      final model = viewModel();

      await model.load();

      expect(model.state, AdministrationState.error);
      expect(model.errorMessage, 'Your role may not do that.');
    });

    test('the fields are checked before the API is asked', () {
      final model = viewModel();

      expect(model.validateEmail(''), isNull);
      expect(model.validateEmail('rita@hotel.dk'), isNull);
      expect(model.validateEmail('rita.hotel.dk'), Strings.emailInvalid);
      expect(model.validateEmail('@hotel.dk'), Strings.emailInvalid);
      expect(model.validatePassword('short'), Strings.passwordTooShort);
      expect(model.validatePassword('twelve chars'), isNull);
      expect(model.validateRequired(' ', 'x'), 'x');
    });
  });

  group('AdministrationScreen', () {
    Future<void> show(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: AdministrationScreen(viewModel: viewModel())),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(WidgetTester tester, int id) async {
      await tester.tap(find.byKey(ValueKey('accountMenu-$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the accounts with their name, address and state', (
      tester,
    ) async {
      await show(tester);

      expect(find.text('Mia Holm (${Strings.you})'), findsOneWidget);
      expect(find.text('Rita Hansen'), findsOneWidget);
      expect(
        find.text(
          'rita · rita@hotel.dk\nReceptionist · ${Strings.stateActive}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('otto\nReceptionist · ${Strings.stateDisabled}'),
        findsOneWidget,
      );
    });

    testWidgets('the own account offers only its name and address', (
      tester,
    ) async {
      await show(tester);

      await openMenu(tester, 1);

      expect(find.text(Strings.editName), findsOneWidget);
      expect(find.text(Strings.editEmail), findsOneWidget);
      expect(find.text(Strings.deleteAccount), findsNothing);
      expect(find.text(Strings.changeRole), findsNothing);
    });

    testWidgets('a deletion asks first, then deletes and says so', (
      tester,
    ) async {
      await show(tester);

      await openMenu(tester, 4);
      await tester.tap(find.byKey(const ValueKey('delete-4')));
      await tester.pumpAndSettle();
      expect(find.text(Strings.deleteQuestion('rita')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirmAction')));
      await tester.pumpAndSettle();

      expect(staff.calls, ['delete:4']);
      expect(find.text(Strings.accountDeleted('rita')), findsOneWidget);
      expect(find.byKey(const ValueKey('account-4')), findsNothing);
    });

    testWidgets('a cancelled deletion changes nothing', (tester) async {
      await show(tester);

      await openMenu(tester, 4);
      await tester.tap(find.byKey(const ValueKey('delete-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();

      expect(staff.calls, isEmpty);
      expect(find.byKey(const ValueKey('account-4')), findsOneWidget);
    });

    testWidgets('a new role is chosen from the roles', (tester) async {
      await show(tester);

      await openMenu(tester, 4);
      await tester.tap(find.byKey(const ValueKey('changeRole-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('role-manager')));
      await tester.pumpAndSettle();

      expect(staff.calls, ['role:4:manager']);
      expect(find.text(Strings.roleChanged('rita')), findsOneWidget);
    });

    testWidgets('a name is edited in a dialog with the old name in it', (
      tester,
    ) async {
      await show(tester);

      await openMenu(tester, 4);
      await tester.tap(find.byKey(const ValueKey('editName-4')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Rita'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('dialogField-1')),
        'Holm',
      );
      await tester.tap(find.byKey(const ValueKey('dialogSave')));
      await tester.pumpAndSettle();

      expect(staff.calls, ['rename:4:Rita Holm']);
    });

    testWidgets('a disabled account is enabled without a question', (
      tester,
    ) async {
      await show(tester);

      await openMenu(tester, 7);
      await tester.tap(find.byKey(const ValueKey('toggleActive-7')));
      await tester.pumpAndSettle();

      expect(staff.calls, ['enable:7']);
      expect(find.text(Strings.accountEnabled('otto')), findsOneWidget);
    });

    testWidgets('a refused change shows the text of its code', (tester) async {
      staff.changeFailure = const ApiFailure(FailureKind.rejected, [
        'staff.email_taken',
      ]);
      await show(tester);

      await openMenu(tester, 4);
      await tester.tap(find.byKey(const ValueKey('editEmail-4')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('dialogField-0')),
        'mia@hotel.dk',
      );
      await tester.tap(find.byKey(const ValueKey('dialogSave')));
      await tester.pumpAndSettle();

      expect(
        find.text('Another account already has that e-mail address.'),
        findsOneWidget,
      );
    });

    testWidgets('a new account is checked, then created with its fields', (
      tester,
    ) async {
      await show(tester);

      await tester.tap(find.byKey(const ValueKey('createAccount')));
      await tester.pumpAndSettle();
      expect(find.text(Strings.firstNameRequired), findsOneWidget);
      expect(find.text(Strings.passwordTooShort), findsOneWidget);
      expect(staff.created, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('newFirstName')),
        'Lena',
      );
      await tester.enterText(find.byKey(const ValueKey('newLastName')), 'Berg');
      await tester.enterText(find.byKey(const ValueKey('newUserName')), 'lena');
      await tester.enterText(
        find.byKey(const ValueKey('newEmail')),
        'lena@hotel.dk',
      );
      await tester.enterText(
        find.byKey(const ValueKey('newPassword')),
        'temporary passphrase 7',
      );
      await tester.tap(find.byKey(const ValueKey('createAccount')));
      await tester.pumpAndSettle();

      final created = staff.created.single;
      expect(
        (created.firstName, created.lastName, created.userName, created.email),
        ('Lena', 'Berg', 'lena', 'lena@hotel.dk'),
      );
      expect(created.role, StaffRole.housekeeping);
      expect(find.text(Strings.accountCreated('lena')), findsOneWidget);
      expect(find.text('Lena Berg'), findsOneWidget);
    });
  });
}
