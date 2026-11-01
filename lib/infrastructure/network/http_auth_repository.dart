import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_json.dart';

/// Signs in with `POST /api/auth/login`.
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
}
