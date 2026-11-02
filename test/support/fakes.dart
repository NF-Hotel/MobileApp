import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/room_service_note.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/domain/repositories/room_service_note_repository.dart';
import 'package:mobil_application/domain/repositories/session_store.dart';
import 'package:mobil_application/domain/result.dart';

/// A fixed point in time for the tests.
final DateTime testNow = DateTime.utc(2026, 10, 20, 8);

/// A session that is valid at [testNow].
StaffSession validSession({StaffRole role = StaffRole.housekeeping}) =>
    StaffSession(
      token: 'token-1',
      expiresAt: testNow.add(const Duration(hours: 8)),
      userName: 'hilda',
      role: role,
    );

/// A room with the given state; the actions default to none.
Room room({
  int id = 1,
  String number = '101',
  int floor = 1,
  HousekeepingStatus housekeeping = HousekeepingStatus.clean,
  RoomStatus status = RoomStatus.available,
  RoomActions actions = const RoomActions(),
}) => Room(
  roomId: id,
  roomNumber: number,
  floor: floor,
  size: RoomSize.double,
  capacity: 2,
  status: status,
  housekeepingStatus: housekeeping,
  actions: actions,
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

/// Answers the sign-in with a fixed result and remembers what it was asked.
class FakeAuthRepository implements AuthRepository {
  /// Creates the fake.
  FakeAuthRepository(this.result);

  /// What the sign-in returns.
  Result<StaffSession> result;

  /// The user names it was called with.
  final List<String> userNames = <String>[];

  @override
  Future<Result<StaffSession>> signIn(String userName, String password) async {
    userNames.add(userName);
    return result;
  }
}

/// A service note; it is open unless [doneBy] is given.
RoomServiceNote serviceNote({
  int id = 1,
  int roomId = 1,
  String text = 'The tap drips',
  String writtenBy = 'hilda',
  String? doneBy,
}) => RoomServiceNote(
  id: id,
  roomId: roomId,
  text: text,
  writtenBy: writtenBy,
  writtenAt: testNow,
  doneBy: doneBy,
  doneAt: doneBy == null ? null : testNow,
  undoableUntil: doneBy == null
      ? null
      : testNow.add(const Duration(minutes: 5)),
);

/// Holds service notes in memory and records the changes done on them. A test
/// plays the five minutes by moving a note to [history] and by setting
/// [changeFailure] to what the API answers.
class FakeRoomServiceNoteRepository implements RoomServiceNoteRepository {
  /// Creates the fake with [current] and [history].
  FakeRoomServiceNoteRepository({
    List<RoomServiceNote>? current,
    List<RoomServiceNote>? history,
    this.userName = 'hilda',
  }) : current = current ?? <RoomServiceNote>[],
       history = history ?? <RoomServiceNote>[];

  /// The notes that are not in the history.
  List<RoomServiceNote> current;

  /// The notes in the history.
  List<RoomServiceNote> history;

  /// Who is calling, for the names on the notes.
  final String userName;

  /// Set to make every call fail.
  ApiFailure? failure;

  /// Set to make only the changes fail, so that the notes can still be read.
  ApiFailure? changeFailure;

  /// The changes asked for, as `action:noteId`, or `create:roomId:text`.
  final List<String> changes = <String>[];

  /// How many times the current notes were read.
  int currentReads = 0;

  /// Runs at each read of the current notes, before its answer is taken.
  Future<void> Function()? beforeReadCurrent;

  int _nextId = 100;

  @override
  Future<Result<List<RoomServiceNote>>> readCurrent() async {
    currentReads++;
    final failed = failure;
    if (failed != null) {
      return Failed(failed);
    }
    final answer = [...current];
    await beforeReadCurrent?.call();
    return Success(answer);
  }

  @override
  Future<Result<List<RoomServiceNote>>> readHistory(int roomId) async {
    final failed = failure;
    return failed == null
        ? Success(history.where((n) => n.roomId == roomId).toList())
        : Failed(failed);
  }

  @override
  Future<Result<RoomServiceNote>> create(int roomId, String text) async {
    changes.add('create:$roomId:$text');
    final failed = failure ?? changeFailure;
    if (failed != null) {
      return Failed(failed);
    }
    final note = serviceNote(
      id: _nextId++,
      roomId: roomId,
      text: text,
      writtenBy: userName,
    );
    current = [...current, note];
    return Success(note);
  }

  @override
  Future<Result<RoomServiceNote>> markDone(int noteId) =>
      _change('markDone', noteId, doneBy: userName);

  @override
  Future<Result<RoomServiceNote>> undoDone(int noteId) =>
      _change('undoDone', noteId);

  @override
  Future<Result<RoomServiceNote>> reopen(int noteId) async {
    changes.add('reopen:$noteId');
    final failed = failure ?? changeFailure;
    if (failed != null) {
      return Failed(failed);
    }
    final old = history.firstWhere((n) => n.id == noteId);
    final note = serviceNote(
      id: old.id,
      roomId: old.roomId,
      text: old.text,
      writtenBy: old.writtenBy,
    );
    history = history.where((n) => n.id != noteId).toList();
    current = [...current, note];
    return Success(note);
  }

  Future<Result<RoomServiceNote>> _change(
    String action,
    int noteId, {
    String? doneBy,
  }) async {
    changes.add('$action:$noteId');
    final failed = failure ?? changeFailure;
    if (failed != null) {
      return Failed(failed);
    }
    final old = current.firstWhere((n) => n.id == noteId);
    final note = serviceNote(
      id: old.id,
      roomId: old.roomId,
      text: old.text,
      writtenBy: old.writtenBy,
      doneBy: doneBy,
    );
    current = [for (final n in current) n.id == noteId ? note : n];
    return Success(note);
  }
}

/// Holds rooms in memory and records the actions done on them.
class FakeRoomRepository implements RoomRepository {
  /// Creates the fake with [rooms].
  FakeRoomRepository(this.rooms);

  /// The rooms it returns.
  List<Room> rooms;

  /// Set to make every call fail.
  ApiFailure? failure;

  /// What [perform] returns on success; defaults to the room unchanged.
  Room Function(int roomId, RoomAction action, bool requiresCleaning)?
  onPerform;

  /// The calls to [perform], as `roomId:action:requiresCleaning`.
  final List<String> performed = <String>[];

  @override
  Future<Result<List<Room>>> readAll() async {
    final failed = failure;
    return failed == null ? Success(rooms) : Failed(failed);
  }

  @override
  Future<Result<Room>> read(int roomId) async {
    final failed = failure;
    if (failed != null) {
      return Failed(failed);
    }
    return Success(rooms.firstWhere((r) => r.roomId == roomId));
  }

  @override
  Future<Result<Room>> perform(
    int roomId,
    RoomAction action, {
    bool requiresCleaning = false,
  }) async {
    performed.add('$roomId:${action.name}:$requiresCleaning');
    final failed = failure;
    if (failed != null) {
      return Failed(failed);
    }
    final change = onPerform;
    final updated = change == null
        ? rooms.firstWhere((r) => r.roomId == roomId)
        : change(roomId, action, requiresCleaning);
    rooms = [for (final r in rooms) r.roomId == roomId ? updated : r];
    return Success(updated);
  }
}
