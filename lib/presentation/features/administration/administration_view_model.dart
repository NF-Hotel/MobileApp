import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/entities/staff_account.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/staff_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// What the administration is doing.
enum AdministrationState {
  /// Reading the accounts.
  loading,

  /// The accounts are shown.
  ready,

  /// Reading failed; [AdministrationViewModel.errorMessage] says why.
  error,
}

/// The answer to one change: whether it was saved, and the text to show.
typedef AdministrationOutcome = ({bool saved, String message});

/// The administration of a Manager (MIL-059): the list of accounts, a new
/// account, and the changes of one. The view model offers what the API allows;
/// the API checks the role and every rule again.
class AdministrationViewModel extends ChangeNotifier {
  /// Creates the view model for the Manager with the user name [ownUserName].
  AdministrationViewModel({required this._staff, required this._ownUserName});

  /// The shortest temporary password that the API accepts.
  static const int minPasswordLength = 12;

  /// The longest name, as the API stores it.
  static const int maxNameLength = 50;

  final StaffRepository _staff;
  final String _ownUserName;

  AdministrationState _state = AdministrationState.loading;
  List<StaffAccount> _accounts = const <StaffAccount>[];
  String? _errorMessage;
  bool _isBusy = false;

  /// What the administration is doing.
  AdministrationState get state => _state;

  /// The accounts, ordered by user name.
  List<StaffAccount> get accounts => _accounts;

  /// The text of the failure when [state] is [AdministrationState.error].
  String? get errorMessage => _errorMessage;

  /// True while a change is being saved.
  bool get isBusy => _isBusy;

  /// True for the account of the Manager who is signed in: its role, state and
  /// password are not changed here, and it cannot be deleted.
  bool isOwn(StaffAccount account) => account.userName == _ownUserName;

  /// The problem with a required text as typed, or null.
  String? validateRequired(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  /// The problem with an optional e-mail address as typed, or null.
  String? validateEmail(String? value) {
    final address = value?.trim() ?? '';
    if (address.isEmpty) {
      return null;
    }
    final at = address.indexOf('@');
    return at <= 0 || at == address.length - 1 || address.contains(' ')
        ? Strings.emailInvalid
        : null;
  }

  /// The problem with a temporary password as typed, or null.
  String? validatePassword(String? value) =>
      value == null || value.length < minPasswordLength
      ? Strings.passwordTooShort
      : null;

  /// Reads the accounts again.
  Future<void> load() async {
    _state = AdministrationState.loading;
    _errorMessage = null;
    notifyListeners();
    await _read();
    notifyListeners();
  }

  /// Creates an account; the member must change the password at the first
  /// sign-in.
  Future<AdministrationOutcome> create(NewStaffAccount account) => _change(
    () => _staff.create(account),
    Strings.accountCreated(account.userName.trim().toLowerCase()),
  );

  /// Sets the first and the last name of [account].
  Future<AdministrationOutcome> rename(
    StaffAccount account,
    String firstName,
    String lastName,
  ) => _change(
    () => _staff.rename(account.id, firstName.trim(), lastName.trim()),
    Strings.accountSaved(account.userName),
  );

  /// Sets the e-mail address of [account]; an empty one clears it.
  Future<AdministrationOutcome> changeEmail(
    StaffAccount account,
    String email,
  ) {
    final address = email.trim();
    return _change(
      () => _staff.changeEmail(account.id, address.isEmpty ? null : address),
      Strings.accountSaved(account.userName),
    );
  }

  /// Gives [account] another role, which ends its sessions.
  Future<AdministrationOutcome> changeRole(
    StaffAccount account,
    StaffRole role,
  ) => _change(
    () => _staff.changeRole(account.id, role),
    Strings.roleChanged(account.userName),
  );

  /// Sets a temporary password for [account].
  Future<AdministrationOutcome> resetPassword(
    StaffAccount account,
    String temporaryPassword,
  ) => _change(
    () => _staff.resetPassword(account.id, temporaryPassword),
    Strings.passwordReset(account.userName),
  );

  /// Disables [account], or enables it again when [active] is true.
  Future<AdministrationOutcome> setActive(StaffAccount account, bool active) =>
      active
      ? _change(
          () => _staff.enable(account.id),
          Strings.accountEnabled(account.userName),
        )
      : _change(
          () => _staff.disable(account.id),
          Strings.accountDisabled(account.userName),
        );

  /// Deletes [account] for good.
  Future<AdministrationOutcome> delete(StaffAccount account) => _change(
    () => _staff.delete(account.id),
    Strings.accountDeleted(account.userName),
  );

  /// Runs one change and reads the accounts again either way: a refused change
  /// can mean that the list is out of date.
  Future<AdministrationOutcome> _change(
    Future<Result<void>> Function() call,
    String success,
  ) async {
    if (_isBusy) {
      return (saved: false, message: '');
    }
    _isBusy = true;
    notifyListeners();

    final result = await call();
    final outcome = switch (result) {
      Success() => (saved: true, message: success),
      Failed(:final failure) => (
        saved: false,
        message: Strings.staffFailure(failure),
      ),
    };
    await _read();

    _isBusy = false;
    notifyListeners();
    return outcome;
  }

  Future<void> _read() async {
    final result = await _staff.readAll();
    switch (result) {
      case Success(:final value):
        _accounts = value;
        _state = AdministrationState.ready;
        _errorMessage = null;
      case Failed(:final failure):
        _errorMessage = Strings.staffFailure(failure);
        _state = AdministrationState.error;
    }
  }
}
