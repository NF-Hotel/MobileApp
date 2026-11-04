import 'package:mobil_application/domain/entities/staff_account.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';

/// The staff accounts through the API, for a Manager (MIL-059, ADR-0017). The
/// API checks the role and every rule again: the own account and the last
/// active Manager can be neither disabled, deleted nor given another role.
abstract interface class StaffRepository {
  /// All accounts, ordered by user name.
  Future<Result<List<StaffAccount>>> readAll();

  /// Creates an account that must choose a new password at the first sign-in.
  Future<Result<void>> create(NewStaffAccount account);

  /// Sets the first and the last name of an account.
  Future<Result<void>> rename(int id, String firstName, String lastName);

  /// Sets the e-mail address of an account; null or empty clears it.
  Future<Result<void>> changeEmail(int id, String? email);

  /// Gives an account another role, which ends its sessions.
  Future<Result<void>> changeRole(int id, StaffRole role);

  /// Sets a temporary password that the member must change at the next
  /// sign-in, and ends the sessions of the account.
  Future<Result<void>> resetPassword(int id, String temporaryPassword);

  /// Disables an account, which ends its sessions.
  Future<Result<void>> disable(int id);

  /// Enables a disabled account; the member must choose a new password.
  Future<Result<void>> enable(int id);

  /// Deletes an account for good. The audit trail keeps the user name.
  Future<Result<void>> delete(int id);
}
