import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_json.dart';

/// Reads and changes rooms through `/api/rooms`.
class HttpRoomRepository implements RoomRepository {
  /// Creates the repository over [client].
  const HttpRoomRepository(this._client);

  static const String _rooms = '/api/rooms';

  final ApiClient _client;

  @override
  Future<Result<List<Room>>> readAll() => _client.get(_rooms, ApiJson.rooms);

  @override
  Future<Result<Room>> read(int roomId) =>
      _client.get('$_rooms/$roomId', ApiJson.room);

  @override
  Future<Result<Room>> perform(
    int roomId,
    RoomAction action, {
    bool requiresCleaning = false,
  }) => _client.post(
    '$_rooms/$roomId/${_segment(action)}',
    ApiJson.room,
    query: action == RoomAction.completeService
        ? <String, String>{'requiresCleaning': '$requiresCleaning'}
        : null,
  );

  static String _segment(RoomAction action) => switch (action) {
    RoomAction.markDailyCleaningDue => 'mark-daily-cleaning-due',
    RoomAction.markDepartureCleaningDue => 'mark-departure-cleaning-due',
    RoomAction.startCleaning => 'start-cleaning',
    RoomAction.completeCleaning => 'complete-cleaning',
    RoomAction.reportServiceNeeded => 'report-service-needed',
    RoomAction.startService => 'start-service',
    RoomAction.completeService => 'complete-service',
  };
}
