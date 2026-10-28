import 'dart:convert';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';

/// Reads the JSON of the API into the entities of the app. A shape that does
/// not fit is a [FormatException], which the client turns into a server
/// failure.
abstract final class ApiJson {
  /// The claim `ClaimTypes.Role` of .NET; the API writes the role under it.
  static const String _roleClaim =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

  /// Reads the session from `{ "accessToken": ... }`, the answer of
  /// `POST /auth/login` and `PUT /me/name`.
  static StaffSession session(Object? json) =>
      sessionFromToken(_string(_map(json), 'accessToken'));

  /// Reads the claims of an access token. The app does not check the
  /// signature: that is the business of the API, which refuses a bad token.
  static StaffSession sessionFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('The token is not a JWT.');
    }
    final claims = _map(
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))),
    );
    final exp = claims['exp'];
    if (exp is! int) {
      throw const FormatException('"exp" should be a whole number.');
    }
    return StaffSession(
      token: token,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
      email: _string(claims, 'email'),
      firstName: _optionalString(claims, 'given_name') ?? '',
      lastName: _optionalString(claims, 'family_name') ?? '',
      role: _enum(claims[_roleClaim] ?? claims['role'], StaffRole.values),
    );
  }

  /// Reads one room of `GET /rooms`.
  static Room room(Object? json) {
    final map = _map(json);
    final cleaners = map['cleaners'];
    return Room(
      number: _int(map, 'number'),
      name: _string(map, 'name'),
      status: _enum(map['status'], RoomStatus.values),
      cleaners: cleaners is List<Object?>
          ? cleaners.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }

  /// Reads the list of `GET /rooms`.
  static List<Room> rooms(Object? json) => _list(json).map(room).toList();

  /// Reads one note of `GET /rooms/{room}/notes`.
  static RoomNote note(Object? json) {
    final map = _map(json);
    final resolvedAt = _optionalString(map, 'resolvedAt');
    return RoomNote(
      id: _int(map, 'id'),
      body: _string(map, 'body'),
      createdBy: _string(map, 'createdBy'),
      createdAt: DateTime.parse(_string(map, 'createdAt')),
      resolvedBy: _optionalString(map, 'resolvedBy'),
      resolvedAt: resolvedAt == null ? null : DateTime.parse(resolvedAt),
    );
  }

  /// Reads the list of `GET /rooms/{room}/notes`.
  static List<RoomNote> notes(Object? json) => _list(json).map(note).toList();

  static Map<String, Object?> _map(Object? json) {
    if (json is Map<String, Object?>) {
      return json;
    }
    throw const FormatException('An object was expected.');
  }

  static List<Object?> _list(Object? json) {
    if (json is List<Object?>) {
      return json;
    }
    throw const FormatException('A list was expected.');
  }

  static String _string(Map<String, Object?> map, String key) =>
      _optionalString(map, key) ??
      (throw FormatException('"$key" should be text.'));

  static String? _optionalString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null || value is String) {
      return value as String?;
    }
    throw FormatException('"$key" should be text.');
  }

  static int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    throw FormatException('"$key" should be a whole number.');
  }

  /// Reads an enum from its name, as the API stores it.
  static T _enum<T extends Enum>(Object? value, List<T> values) {
    final found = value is String ? values.asNameMap()[value] : null;
    return found ?? (throw FormatException('"$value" is not a known value.'));
  }
}
