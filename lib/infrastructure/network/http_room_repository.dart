import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_json.dart';

/// Reads and changes rooms and their notes through `/rooms`.
class HttpRoomRepository implements RoomRepository {
  /// Creates the repository over [client].
  const HttpRoomRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<Room>>> readAll() => _client.get('/rooms', ApiJson.rooms);

  @override
  Future<Result<void>> setStatus(int room, RoomStatus status) => _client.send(
    'PUT',
    '/rooms/$room/status',
    body: <String, Object?>{'status': status.name},
  );

  @override
  Future<Result<List<RoomNote>>> readNotes(int room) =>
      _client.get('/rooms/$room/notes', ApiJson.notes);

  @override
  Future<Result<void>> addNote(int room, String body) => _client.send(
    'POST',
    '/rooms/$room/notes',
    body: <String, Object?>{'body': body},
  );

  @override
  Future<Result<void>> setResolved(int room, int noteId, bool resolved) =>
      _client.send(
        'PUT',
        '/rooms/$room/notes/$noteId/resolved',
        body: <String, Object?>{'resolved': resolved},
      );

  @override
  Future<Result<void>> deleteNote(int room, int noteId) =>
      _client.send('DELETE', '/rooms/$room/notes/$noteId');
}
