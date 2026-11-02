import 'package:mobil_application/domain/entities/room_service_note.dart';
import 'package:mobil_application/domain/repositories/room_service_note_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_json.dart';

/// Reads and changes service notes through `/api/room-service-notes`.
class HttpRoomServiceNoteRepository implements RoomServiceNoteRepository {
  /// Creates the repository over [client].
  const HttpRoomServiceNoteRepository(this._client);

  static const String _notes = '/api/room-service-notes';

  final ApiClient _client;

  @override
  Future<Result<List<RoomServiceNote>>> readCurrent() =>
      _client.get(_notes, ApiJson.serviceNotes);

  @override
  Future<Result<List<RoomServiceNote>>> readHistory(int roomId) =>
      _client.get('$_notes/history/$roomId', ApiJson.serviceNotes);

  @override
  Future<Result<RoomServiceNote>> create(int roomId, String text) =>
      _client.post(
        _notes,
        ApiJson.serviceNote,
        body: <String, Object?>{'roomId': roomId, 'text': text},
      );

  @override
  Future<Result<RoomServiceNote>> markDone(int noteId) =>
      _client.post('$_notes/$noteId/done', ApiJson.serviceNote);

  @override
  Future<Result<RoomServiceNote>> undoDone(int noteId) =>
      _client.post('$_notes/$noteId/undo-done', ApiJson.serviceNote);

  @override
  Future<Result<RoomServiceNote>> reopen(int noteId) =>
      _client.post('$_notes/$noteId/reopen', ApiJson.serviceNote);
}
