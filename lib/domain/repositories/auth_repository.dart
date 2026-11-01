import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';

/// Signs a member of staff in against the API.
abstract interface class AuthRepository {
  /// Signs in with a user name and a password; the result is the session.
  Future<Result<StaffSession>> signIn(String userName, String password);
}
