import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The name of an account that has none, asked after the sign-in (MIL-059).
class NameSetupViewModel extends ChangeNotifier {
  /// Creates the view model.
  NameSetupViewModel({required this._auth, required this._session});

  /// The code of an account that has a name already.
  static const String nameAlreadySetCode = 'staff.name_already_set';

  final AuthRepository _auth;
  final SessionController _session;

  bool _isBusy = false;
  String? _errorMessage;

  /// True while the API is being called.
  bool get isBusy => _isBusy;

  /// The text of the last failure, or null.
  String? get errorMessage => _errorMessage;

  /// The problem with the first name as typed, or null.
  String? validateFirstName(String? value) =>
      value == null || value.trim().isEmpty ? Strings.firstNameRequired : null;

  /// The problem with the last name as typed, or null.
  String? validateLastName(String? value) =>
      value == null || value.trim().isEmpty ? Strings.lastNameRequired : null;

  /// Saves the name. On success the session carries it and the rooms follow.
  /// When a Manager set a name meanwhile, the app goes on without asking again.
  Future<void> submit(String firstName, String lastName) async {
    if (_isBusy ||
        validateFirstName(firstName) != null ||
        validateLastName(lastName) != null) {
      return;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _auth.setOwnName(firstName.trim(), lastName.trim());
    switch (result) {
      case Success(:final value):
        await _session.signIn(value);
      case Failed(:final failure)
          when failure.codes.contains(nameAlreadySetCode):
        _session.skipNameSetup();
      case Failed(:final failure):
        _errorMessage = Strings.staffFailure(failure);
    }

    _isBusy = false;
    notifyListeners();
  }
}
