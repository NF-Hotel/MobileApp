import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/result.dart';

/// Reads rooms and changes their cleaning and service state through the API.
abstract interface class RoomRepository {
  /// All rooms.
  Future<Result<List<Room>>> readAll();

  /// One room by its key.
  Future<Result<Room>> read(int roomId);

  /// Does [action] on the room and returns the room as it is afterwards.
  ///
  /// [requiresCleaning] is used by [RoomAction.completeService] only: whether
  /// cleaning follows the service.
  Future<Result<Room>> perform(
    int roomId,
    RoomAction action, {
    bool requiresCleaning = false,
  });
}
