import 'package:mobil_application/domain/entities/staff_account.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/staff_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_json.dart';

/// Manages the staff accounts through `/api/staff` (MIL-059).
class HttpStaffRepository implements StaffRepository {
  /// Creates the repository over [client].
  const HttpStaffRepository(this._client);

  static const String _staff = '/api/staff';

  final ApiClient _client;

  @override
  Future<Result<List<StaffAccount>>> readAll() =>
      _client.get(_staff, ApiJson.staffAccounts);

  @override
  Future<Result<void>> create(NewStaffAccount account) => _client.post(
    _staff,
    ApiJson.none,
    body: <String, Object?>{
      'userName': account.userName,
      'password': account.temporaryPassword,
      'role': ApiJson.roleNumber(account.role),
      'firstName': account.firstName,
      'lastName': account.lastName,
      'email': account.email,
    },
  );

  @override
  Future<Result<void>> rename(int id, String firstName, String lastName) =>
      _client.post(
        '$_staff/$id/name',
        ApiJson.none,
        body: <String, Object?>{'firstName': firstName, 'lastName': lastName},
      );

  @override
  Future<Result<void>> changeEmail(int id, String? email) => _client.post(
    '$_staff/$id/email',
    ApiJson.none,
    body: <String, Object?>{'email': email},
  );

  @override
  Future<Result<void>> changeRole(int id, StaffRole role) => _client.post(
    '$_staff/$id/role',
    ApiJson.none,
    body: <String, Object?>{'role': ApiJson.roleNumber(role)},
  );

  @override
  Future<Result<void>> resetPassword(int id, String temporaryPassword) =>
      _client.post(
        '$_staff/$id/password',
        ApiJson.none,
        body: <String, Object?>{'newPassword': temporaryPassword},
      );

  @override
  Future<Result<void>> disable(int id) =>
      _client.post('$_staff/$id/disable', ApiJson.none);

  @override
  Future<Result<void>> enable(int id) =>
      _client.post('$_staff/$id/enable', ApiJson.none);

  @override
  Future<Result<void>> delete(int id) =>
      _client.delete('$_staff/$id', ApiJson.none);
}
