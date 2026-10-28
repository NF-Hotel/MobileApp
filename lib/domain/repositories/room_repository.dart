import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/result.dart';

/// Reads rooms and their notes and changes them through the API. A cleaner only
/// sees and changes the rooms they are assigned to.
abstract interface class RoomRepository {
  /// The rooms the signed-in member may see, in the order of their numbers.
  Future<Result<List<Room>>> readAll();

  /// Sets the cleaning state of [room].
  Future<Result<void>> setStatus(int room, RoomStatus status);

  /// The notes of [room], newest first.
  Future<Result<List<RoomNote>>> readNotes(int room);

  /// Adds a note to [room].
  Future<Result<void>> addNote(int room, String body);

  /// Ticks a note off, or ticks it on again.
  Future<Result<void>> setResolved(int room, int noteId, bool resolved);

  /// Deletes a note.
  Future<Result<void>> deleteNote(int room, int noteId);
}
