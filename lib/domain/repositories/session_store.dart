import 'package:mobil_application/domain/entities/staff_session.dart';

/// Keeps the session between runs of the app, in storage that no other app can
/// read.
abstract interface class SessionStore {
  /// The saved session, or null when there is none or it cannot be read.
  Future<StaffSession?> read();

  /// Saves the session.
  Future<void> save(StaffSession session);

  /// Forgets the session.
  Future<void> clear();
}
