import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';

/// Signs a member of staff in against the API.
abstract interface class AuthRepository {
  /// Signs in with an email and a password; the result is the session.
  Future<Result<StaffSession>> signIn(String email, String password);

  /// Sets the name of the signed-in account. This works once, while the
  /// account has no name; the result is a new session whose token carries it.
  Future<Result<StaffSession>> setName(String firstName, String lastName);
}
