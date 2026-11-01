import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';

/// Reads the JSON of the API into the entities of the app. The API sends enums
/// as numbers (`System.Text.Json` web defaults); a name is accepted too. A shape
/// that does not fit is a [FormatException], which the client turns into a
/// server failure.
abstract final class ApiJson {
  /// Reads a session from the value of `POST /api/auth/login`.
  static StaffSession session(Object? json) {
    final map = _map(json);
    return StaffSession(
      token: _string(map, 'token'),
      expiresAt: DateTime.parse(_string(map, 'expiresAt')),
      userName: _string(map, 'userName'),
      role: _enum(map, 'role', StaffRole.values, firstNumber: 1),
    );
  }

  /// Reads one room.
  static Room room(Object? json) {
    final map = _map(json);
    return Room(
      roomId: _int(map, 'roomId'),
      roomNumber: _string(map, 'roomNumber'),
      floor: _int(map, 'floor'),
      size: _enum(map, 'size', RoomSize.values),
      capacity: _int(map, 'capacity'),
      status: _enum(map, 'status', RoomStatus.values),
      housekeepingStatus: _enum(
        map,
        'housekeepingStatus',
        HousekeepingStatus.values,
      ),
      actions: _actions(map['actions']),
    );
  }

  /// Reads a list of rooms.
  static List<Room> rooms(Object? json) {
    if (json is! List<Object?>) {
      throw const FormatException('A list of rooms was expected.');
    }
    return json.map(room).toList(growable: false);
  }

  static RoomActions _actions(Object? json) {
    final map = _map(json);
    bool flag(String key) => map[key] == true;
    return RoomActions(
      canMarkDailyCleaningDue: flag('canMarkDailyCleaningDue'),
      canMarkDepartureCleaningDue: flag('canMarkDepartureCleaningDue'),
      canStartCleaning: flag('canStartCleaning'),
      canCompleteCleaning: flag('canCompleteCleaning'),
      canReportServiceNeeded: flag('canReportServiceNeeded'),
      canStartService: flag('canStartService'),
      canCompleteService: flag('canCompleteService'),
    );
  }

  static Map<String, Object?> _map(Object? json) {
    if (json is Map<String, Object?>) {
      return json;
    }
    throw const FormatException('An object was expected.');
  }

  static String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is String) {
      return value;
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

  /// Reads an enum from its number (counted from [firstNumber]) or its name.
  static T _enum<T extends Enum>(
    Map<String, Object?> map,
    String key,
    List<T> values, {
    int firstNumber = 0,
  }) {
    final value = map[key];
    if (value is int) {
      final index = value - firstNumber;
      if (index >= 0 && index < values.length) {
        return values[index];
      }
    }
    if (value is String) {
      final wanted = value.toLowerCase();
      for (final candidate in values) {
        if (candidate.name.toLowerCase() == wanted) {
          return candidate;
        }
      }
    }
    throw FormatException('"$key" is not a known value.');
  }
}
