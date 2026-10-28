import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/session_store.dart';
import 'package:mobil_application/infrastructure/network/api_json.dart';

/// Keeps the access token in the Keychain (iOS) or the Keystore-backed storage
/// (Android), never in plain preferences. The session is read back from the
/// claims of the token.
class SecureSessionStore implements SessionStore {
  /// Creates the store over [storage].
  const SecureSessionStore(this._storage);

  static const String _key = 'nfhotel.staff_session';

  final FlutterSecureStorage _storage;

  @override
  Future<StaffSession?> read() async {
    try {
      final token = await _storage.read(key: _key);
      return token == null ? null : ApiJson.sessionFromToken(token);
    } on Exception {
      // Unreadable, damaged, or saved by an older version: sign in again.
      return null;
    }
  }

  @override
  Future<void> save(StaffSession session) =>
      _storage.write(key: _key, value: session.token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
