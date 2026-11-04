import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_json.dart';

/// Signs in with `POST /api/auth/login`, and changes the own password and name
/// below `/api/staff/me`.
class HttpAuthRepository implements AuthRepository {
  /// Creates the repository over [client].
  const HttpAuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<StaffSession>> signIn(String userName, String password) =>
      _client.post(
        '/api/auth/login',
        ApiJson.session,
        body: <String, Object?>{'userName': userName, 'password': password},
      );

  @override
  Future<Result<StaffSession>> changePassword(
    String currentPassword,
    String newPassword,
  ) => _client.post(
    '/api/staff/me/password',
    ApiJson.session,
    body: <String, Object?>{
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    },
  );

  @override
  Future<Result<StaffSession>> setOwnName(String firstName, String lastName) =>
      _client.post(
        '/api/staff/me/name',
        ApiJson.session,
        body: <String, Object?>{'firstName': firstName, 'lastName': lastName},
      );
}
