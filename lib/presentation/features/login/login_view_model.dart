import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The state of the sign-in screen and what it does when the member submits.
class LoginViewModel extends ChangeNotifier {
  /// Creates the view model.
  LoginViewModel({required this._auth, required this._session});

  final AuthRepository _auth;
  final SessionController _session;

  bool _isBusy = false;
  String? _errorMessage;

  /// True while the API is being called.
  bool get isBusy => _isBusy;

  /// The text of the last failure, or null.
  String? get errorMessage => _errorMessage;

  /// The problem with the user name as typed, or null.
  String? validateUserName(String? value) =>
      value == null || value.trim().isEmpty ? Strings.userNameRequired : null;

  /// The problem with the password as typed, or null.
  String? validatePassword(String? value) =>
      value == null || value.isEmpty ? Strings.passwordRequired : null;

  /// Signs in. On success the session controller shows the rooms.
  Future<void> submit(String userName, String password) async {
    if (_isBusy ||
        validateUserName(userName) != null ||
        validatePassword(password) != null) {
      return;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _auth.signIn(userName.trim(), password);
    switch (result) {
      case Success(:final value):
        await _session.signIn(value);
      case Failed(:final failure):
        _errorMessage = Strings.failure(failure);
    }

    _isBusy = false;
    notifyListeners();
  }
}
