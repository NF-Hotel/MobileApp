import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/session_store.dart';

/// Holds who is signed in. The app shows the sign-in when there is no session
/// and the rooms when there is one; a token that the API no longer accepts, or
/// that has expired, ends the session.
class SessionController extends ChangeNotifier {
  /// Creates the controller. [now] is the clock, so a test can fix the time.
  SessionController({required this._store, this._now = DateTime.now});

  final SessionStore _store;
  final DateTime Function() _now;

  StaffSession? _session;
  bool _isRestoring = true;

  /// The signed-in member of staff, or null.
  StaffSession? get session => _session;

  /// The staff token to send, or null when nobody is signed in.
  String? get token => _session?.token;

  /// True until the saved session has been read.
  bool get isRestoring => _isRestoring;

  /// Reads the saved session; an expired one is forgotten.
  Future<void> restore() async {
    final saved = await _store.read();
    if (saved != null && !saved.isExpiredAt(_now())) {
      _session = saved;
    } else if (saved != null) {
      await _store.clear();
    }
    _isRestoring = false;
    notifyListeners();
  }

  /// Keeps [session] and shows the rooms.
  Future<void> signIn(StaffSession session) async {
    await _store.save(session);
    _session = session;
    notifyListeners();
  }

  /// Forgets the session and shows the sign-in.
  Future<void> signOut() async {
    _session = null;
    notifyListeners();
    await _store.clear();
  }

  /// Called when the API refuses the token: ends the session.
  void onUnauthorized() {
    if (_session != null) {
      unawaited(signOut());
    }
  }
}
