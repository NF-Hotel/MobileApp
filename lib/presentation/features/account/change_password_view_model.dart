import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The change of the own password, at the first sign-in or later (ADR-0017).
/// The API checks every rule of the password again.
class ChangePasswordViewModel extends ChangeNotifier {
  /// Creates the view model.
  ChangePasswordViewModel({required this._auth, required this._session});

  /// The shortest password that the API accepts.
  static const int minPasswordLength = 12;

  final AuthRepository _auth;
  final SessionController _session;

  bool _isBusy = false;
  String? _errorMessage;

  /// True while the API is being called.
  bool get isBusy => _isBusy;

  /// The text of the last failure, or null.
  String? get errorMessage => _errorMessage;

  /// The problem with the current password as typed, or null.
  String? validateCurrent(String? value) =>
      value == null || value.isEmpty ? Strings.currentPasswordRequired : null;

  /// The problem with the new password as typed, or null.
  String? validateNew(String? value) =>
      value == null || value.length < minPasswordLength
      ? Strings.passwordTooShort
      : null;

  /// The problem with the repeated password, or null.
  String? validateConfirm(String? value, String newPassword) =>
      value != newPassword ? Strings.passwordsDoNotMatch : null;

  /// Changes the password. On success the new session replaces the old one,
  /// whose token has ended; returns true then.
  Future<bool> submit(String current, String newPassword) async {
    if (_isBusy ||
        validateCurrent(current) != null ||
        validateNew(newPassword) != null) {
      return false;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _auth.changePassword(current, newPassword);
    var changed = false;
    switch (result) {
      case Success(:final value):
        await _session.signIn(value);
        changed = true;
      case Failed(:final failure):
        _errorMessage = Strings.staffFailure(failure);
    }

    _isBusy = false;
    notifyListeners();
    return changed;
  }
}
