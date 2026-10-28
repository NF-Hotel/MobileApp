import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// A new account sets its name once, right after the first sign-in.
class NameViewModel extends ChangeNotifier {
  /// Creates the view model.
  NameViewModel({required this._auth, required this._session});

  final AuthRepository _auth;
  final SessionController _session;

  bool _isBusy = false;
  String? _errorMessage;

  /// True while the API is being called.
  bool get isBusy => _isBusy;

  /// The text of the last failure, or null.
  String? get errorMessage => _errorMessage;

  /// The problem with a name as typed, or null.
  String? validate(String? value) =>
      value == null || value.trim().isEmpty ? Strings.required : null;

  /// Saves the name. On success the new token carries it and the rooms show.
  Future<void> submit(String firstName, String lastName) async {
    if (_isBusy || validate(firstName) != null || validate(lastName) != null) {
      return;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _auth.setName(firstName.trim(), lastName.trim());
    switch (result) {
      case Success(:final value):
        await _session.signIn(value);
      // 409: an admin named the account meanwhile; a new sign-in picks it up.
      case Failed(failure: ApiFailure(kind: FailureKind.rejected)):
        _errorMessage = Strings.nameAlreadySet;
      case Failed(:final failure):
        _errorMessage = Strings.failure(failure);
    }

    _isBusy = false;
    notifyListeners();
  }
}
