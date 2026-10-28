import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_json.dart';

/// Signs in with `POST /auth/login` and names the account with `PUT /me/name`.
class HttpAuthRepository implements AuthRepository {
  /// Creates the repository over [client].
  const HttpAuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<StaffSession>> signIn(String email, String password) =>
      _client.send(
        'POST',
        '/auth/login',
        body: <String, Object?>{'email': email, 'password': password},
        parse: ApiJson.session,
      );

  @override
  Future<Result<StaffSession>> setName(String firstName, String lastName) =>
      _client.send(
        'PUT',
        '/me/name',
        body: <String, Object?>{'firstName': firstName, 'lastName': lastName},
        parse: ApiJson.session,
      );
}
