import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';

/// Signs a member of staff in against the API, and changes what the member may
/// change on the own account.
abstract interface class AuthRepository {
  /// Signs in with a user name and a password; the result is the session.
  Future<Result<StaffSession>> signIn(String userName, String password);

  /// Changes the own password. The result is a new session: the old token has
  /// ended (ADR-0017).
  Future<Result<StaffSession>> changePassword(
    String currentPassword,
    String newPassword,
  );

  /// Gives the own account a name while it has none (MIL-059). The result is
  /// the session with the name.
  Future<Result<StaffSession>> setOwnName(String firstName, String lastName);
}
