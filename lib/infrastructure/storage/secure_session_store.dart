import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/session_store.dart';

/// Keeps the session in the Keychain (iOS) or the Keystore-backed storage
/// (Android), never in plain preferences (ADR-0015).
class SecureSessionStore implements SessionStore {
  /// Creates the store over [storage].
  const SecureSessionStore(this._storage);

  static const String _key = 'nfhotel.staff_session';

  final FlutterSecureStorage _storage;

  @override
  Future<StaffSession?> read() async {
    try {
      final text = await _storage.read(key: _key);
      if (text == null) {
        return null;
      }
      final json = jsonDecode(text);
      if (json case {
        'token': final String token,
        'expiresAt': final String expiresAt,
        'userName': final String userName,
        'role': final String role,
      }) {
        final expires = DateTime.tryParse(expiresAt);
        final staffRole = StaffRole.values.asNameMap()[role];
        if (expires != null && staffRole != null) {
          return StaffSession(
            token: token,
            expiresAt: expires,
            userName: userName,
            role: staffRole,
          );
        }
      }
      return null;
    } on Exception {
      // Unreadable or damaged: the member signs in again.
      return null;
    }
  }

  @override
  Future<void> save(StaffSession session) => _storage.write(
    key: _key,
    value: jsonEncode(<String, Object?>{
      'token': session.token,
      'expiresAt': session.expiresAt.toUtc().toIso8601String(),
      'userName': session.userName,
      'role': session.role.name,
    }),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
