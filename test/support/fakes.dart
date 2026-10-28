import 'dart:convert';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/domain/repositories/session_store.dart';
import 'package:mobil_application/domain/result.dart';

/// A fixed point in time for the tests.
final DateTime testNow = DateTime.utc(2026, 10, 20, 8);

/// An unsigned JWT with [claims], shaped like the tokens of the API.
String jwt(Map<String, Object?> claims) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(claims)}.signature';
}

/// A session that is valid at [testNow].
StaffSession validSession({
  StaffRole role = StaffRole.cleaner,
  String email = 'hilda@hotel.test',
  String firstName = 'Hilda',
  String lastName = 'Berg',
}) => StaffSession(
  token: 'token-1',
  expiresAt: testNow.add(const Duration(hours: 8)),
  email: email,
  firstName: firstName,
  lastName: lastName,
  role: role,
);

/// A room with the given state.
Room room({
  int number = 1,
  String name = '101',
  RoomStatus status = RoomStatus.clean,
  List<String> cleaners = const <String>[],
}) => Room(number: number, name: name, status: status, cleaners: cleaners);

/// A note written at [createdAt], by default by the [validSession] member.
RoomNote note({
  int id = 1,
  String body = 'Lamp is broken',
  String createdBy = 'hilda@hotel.test',
  DateTime? createdAt,
  String? resolvedBy,
  DateTime? resolvedAt,
}) => RoomNote(
  id: id,
  body: body,
  createdBy: createdBy,
  createdAt: createdAt ?? testNow,
  resolvedBy: resolvedBy,
  resolvedAt: resolvedAt,
);

/// Keeps the session in memory.
class FakeSessionStore implements SessionStore {
  /// Creates the store, optionally holding [saved].
  FakeSessionStore([this.saved]);

  /// What is stored.
  StaffSession? saved;

  @override
  Future<StaffSession?> read() async => saved;

  @override
  Future<void> save(StaffSession session) async => saved = session;

  @override
  Future<void> clear() async => saved = null;
}

/// Answers with fixed results and remembers what it was asked.
class FakeAuthRepository implements AuthRepository {
  /// Creates the fake.
  FakeAuthRepository(this.result, [Result<StaffSession>? nameResult])
    : nameResult = nameResult ?? Success(validSession());

  /// What the sign-in returns.
  Result<StaffSession> result;

  /// What setting the name returns.
  Result<StaffSession> nameResult;

  /// The emails it was signed in with.
  final List<String> emails = <String>[];

  /// The names it was given, as `first last`.
  final List<String> names = <String>[];

  @override
  Future<Result<StaffSession>> signIn(String email, String password) async {
    emails.add(email);
    return result;
  }

  @override
  Future<Result<StaffSession>> setName(
    String firstName,
    String lastName,
  ) async {
    names.add('$firstName $lastName');
    return nameResult;
  }
}

/// Holds rooms and notes in memory and records the changes made to them.
class FakeRoomRepository implements RoomRepository {
  /// Creates the fake with [rooms].
  FakeRoomRepository(this.rooms);

  /// The rooms it returns.
  List<Room> rooms;

  /// The notes by room number.
  final Map<int, List<RoomNote>> notes = <int, List<RoomNote>>{};

  /// Set to make every call fail.
  ApiFailure? failure;

  /// The changes, as `method:room:detail`.
  final List<String> calls = <String>[];

  var _nextNoteId = 100;

  Result<T> _answer<T>(T Function() value) {
    final failed = failure;
    return failed == null ? Success(value()) : Failed(failed);
  }

  @override
  Future<Result<List<Room>>> readAll() async => _answer(() => rooms);

  @override
  Future<Result<void>> setStatus(int room, RoomStatus status) async {
    calls.add('setStatus:$room:${status.name}');
    return _answer(() {
      rooms = [
        for (final r in rooms) r.number == room ? r.withStatus(status) : r,
      ];
    });
  }

  @override
  Future<Result<List<RoomNote>>> readNotes(int room) async =>
      _answer(() => notes[room] ?? const <RoomNote>[]);

  @override
  Future<Result<void>> addNote(int room, String body) async {
    calls.add('addNote:$room:$body');
    return _answer(() {
      notes[room] = [note(id: _nextNoteId++, body: body), ...?notes[room]];
    });
  }

  @override
  Future<Result<void>> setResolved(int room, int noteId, bool resolved) async {
    calls.add('setResolved:$room:$noteId:$resolved');
    return _answer(() {
      notes[room] = [
        for (final n in notes[room] ?? const <RoomNote>[])
          n.id != noteId
              ? n
              : RoomNote(
                  id: n.id,
                  body: n.body,
                  createdBy: n.createdBy,
                  createdAt: n.createdAt,
                  resolvedBy: resolved ? 'hilda@hotel.test' : null,
                  resolvedAt: resolved ? testNow : null,
                ),
      ];
    });
  }

  @override
  Future<Result<void>> deleteNote(int room, int noteId) async {
    calls.add('deleteNote:$room:$noteId');
    return _answer(() => notes[room]?.removeWhere((n) => n.id == noteId));
  }
}
