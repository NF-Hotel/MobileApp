import 'package:mobil_application/domain/entities/room_service_note.dart';
import 'package:mobil_application/domain/result.dart';

/// Reads the service notes of the rooms and changes them through the API.
abstract interface class RoomServiceNoteRepository {
  /// The notes of every room that are not in the history, oldest first.
  Future<Result<List<RoomServiceNote>>> readCurrent();

  /// The finished service of a room, most recently done first.
  Future<Result<List<RoomServiceNote>>> readHistory(int roomId);

  /// Writes a note on a room, which also reports that it needs service. The API
  /// takes the name of the writer from the staff token.
  Future<Result<RoomServiceNote>> create(int roomId, String text);

  /// Marks a note as done.
  Future<Result<RoomServiceNote>> markDone(int noteId);

  /// Undoes the mark of a note that is not yet in the history.
  Future<Result<RoomServiceNote>> undoDone(int noteId);

  /// Takes a note back from the history. For a Manager only.
  Future<Result<RoomServiceNote>> reopen(int noteId);
}
