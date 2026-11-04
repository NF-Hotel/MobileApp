import 'package:mobil_application/domain/entities/planning.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/planning_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_json.dart';

/// The shifts, the room assignments and their trades through `/api/shifts`,
/// `/api/shift-trades`, `/api/room-assignments` and `/api/room-trades`
/// (MIL-060).
class HttpPlanningRepository implements PlanningRepository {
  /// Creates the repository over [client].
  const HttpPlanningRepository(this._client);

  static const String _shifts = '/api/shifts';
  static const String _shiftTrades = '/api/shift-trades';
  static const String _assignments = '/api/room-assignments';
  static const String _roomTrades = '/api/room-trades';

  final ApiClient _client;

  @override
  Future<Result<List<Shift>>> readShifts(DateTime from, DateTime to) =>
      _client.get(
        _shifts,
        ApiJson.shifts,
        query: <String, String>{'from': _moment(from), 'to': _moment(to)},
      );

  @override
  Future<Result<Shift>> createShift(
    DateTime startsAt,
    DateTime endsAt,
    StaffRole role,
    int? assigneeId,
  ) => _client.post(
    _shifts,
    ApiJson.shift,
    body: _shiftBody(startsAt, endsAt, role, assigneeId),
  );

  @override
  Future<Result<Shift>> updateShift(
    int id,
    DateTime startsAt,
    DateTime endsAt,
    StaffRole role,
    int? assigneeId,
  ) => _client.put(
    '$_shifts/$id',
    ApiJson.shift,
    body: _shiftBody(startsAt, endsAt, role, assigneeId),
  );

  @override
  Future<Result<void>> deleteShift(int id) =>
      _client.delete('$_shifts/$id', ApiJson.none);

  @override
  Future<Result<List<ShiftTrade>>> readShiftTrades() =>
      _client.get(_shiftTrades, ApiJson.shiftTrades);

  @override
  Future<Result<ShiftTrade>> offerShift(int shiftId, {int? swapShiftId}) =>
      _client.post(
        _shiftTrades,
        ApiJson.shiftTrade,
        body: <String, Object?>{'shiftId': shiftId, 'swapShiftId': swapShiftId},
      );

  @override
  Future<Result<ShiftTrade>> stepShiftTrade(int id, TradeStep step) =>
      _client.post('$_shiftTrades/$id/${step.name}', ApiJson.shiftTrade);

  @override
  Future<Result<RoomAssignmentOverview>> readRoomAssignments() =>
      _client.get(_assignments, ApiJson.roomAssignments);

  @override
  Future<Result<void>> assignRoom(int roomId, int? staffId) => _client.put(
    '$_assignments/$roomId',
    ApiJson.none,
    body: <String, Object?>{'staffId': staffId},
  );

  @override
  Future<Result<List<RoomTrade>>> readRoomTrades() =>
      _client.get(_roomTrades, ApiJson.roomTrades);

  @override
  Future<Result<RoomTrade>> offerRooms(
    int toStaffId,
    List<int> giveRoomIds,
    List<int> takeRoomIds,
  ) => _client.post(
    _roomTrades,
    ApiJson.roomTrade,
    body: <String, Object?>{
      'toStaffId': toStaffId,
      'giveRoomIds': giveRoomIds,
      'takeRoomIds': takeRoomIds,
    },
  );

  @override
  Future<Result<RoomTrade>> stepRoomTrade(int id, TradeStep step) =>
      _client.post('$_roomTrades/$id/${step.name}', ApiJson.roomTrade);

  static Map<String, Object?> _shiftBody(
    DateTime startsAt,
    DateTime endsAt,
    StaffRole role,
    int? assigneeId,
  ) => <String, Object?>{
    'startsAt': _moment(startsAt),
    'endsAt': _moment(endsAt),
    'role': ApiJson.roleNumber(role),
    'assigneeId': assigneeId,
  };

  static String _moment(DateTime value) => value.toUtc().toIso8601String();
}
