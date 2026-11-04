import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/room_service_note.dart';
import 'package:mobil_application/domain/entities/staff_account.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/domain/repositories/room_service_note_repository.dart';
import 'package:mobil_application/domain/repositories/session_store.dart';
import 'package:mobil_application/domain/repositories/staff_repository.dart';
import 'package:mobil_application/domain/result.dart';

/// A fixed point in time for the tests.
final DateTime testNow = DateTime.utc(2026, 10, 20, 8);

/// A session that is valid at [testNow].
StaffSession validSession({
  StaffRole role = StaffRole.housekeeping,
  bool mustChangePassword = false,
  String? firstName,
  String? lastName,
  String token = 'token-1',
}) => StaffSession(
  token: token,
  expiresAt: testNow.add(const Duration(hours: 8)),
  userName: 'hilda',
  role: role,
  mustChangePassword: mustChangePassword,
  firstName: firstName,
  lastName: lastName,
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

/// Answers the sign-in and the changes of the own account with fixed results
/// and remembers what it was asked.
class FakeAuthRepository implements AuthRepository {
  /// Creates the fake.
  FakeAuthRepository(this.result, {this.changeResult, this.nameResult});

  /// What the sign-in returns.
  Result<StaffSession> result;

  /// What the change of the password returns; the sign-in result when null.
  Result<StaffSession>? changeResult;

  /// What the own name returns; the sign-in result when null.
  Result<StaffSession>? nameResult;

  /// The user names it was called with.
  final List<String> userNames = <String>[];

  /// The changes of the password, as `current>new`.
  final List<String> passwordChanges = <String>[];

  /// The names it was given, as `first last`.
  final List<String> names = <String>[];

  @override
  Future<Result<StaffSession>> signIn(String userName, String password) async {
    userNames.add(userName);
    return result;
  }

  @override
  Future<Result<StaffSession>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    passwordChanges.add('$currentPassword>$newPassword');
    return changeResult ?? result;
  }

  @override
  Future<Result<StaffSession>> setOwnName(
    String firstName,
    String lastName,
  ) async {
    names.add('$firstName $lastName');
    return nameResult ?? result;
  }
}

/// A staff account for the administration.
StaffAccount staffAccount({
  int id = 1,
  String userName = 'rita',
  StaffRole role = StaffRole.receptionist,
  bool isActive = true,
  bool mustChangePassword = false,
  String? firstName,
  String? lastName,
  String? email,
}) => StaffAccount(
  id: id,
  userName: userName,
  role: role,
  isActive: isActive,
  mustChangePassword: mustChangePassword,
  firstName: firstName,
  lastName: lastName,
  email: email,
);

/// Holds staff accounts in memory and records the changes asked of it.
class FakeStaffRepository implements StaffRepository {
  /// Creates the fake with [accounts].
  FakeStaffRepository([List<StaffAccount>? accounts])
    : accounts = accounts ?? <StaffAccount>[];

  /// The accounts it returns.
  List<StaffAccount> accounts;

  /// Set to make every change fail; the list is still read.
  ApiFailure? changeFailure;

  /// Set to make reading the list fail.
  ApiFailure? readFailure;

  /// The changes, as `action:id` or `action:id:detail`.
  final List<String> calls = <String>[];

  /// The accounts that were created.
  final List<NewStaffAccount> created = <NewStaffAccount>[];

  @override
  Future<Result<List<StaffAccount>>> readAll() async {
    final failed = readFailure;
    return failed == null ? Success(accounts) : Failed(failed);
  }

  @override
  Future<Result<void>> create(NewStaffAccount account) {
    created.add(account);
    return _change('create:${account.userName}', () {
      accounts = [
        ...accounts,
        staffAccount(
          id: accounts.length + 100,
          userName: account.userName,
          role: account.role,
          mustChangePassword: true,
          firstName: account.firstName,
          lastName: account.lastName,
          email: account.email,
        ),
      ];
    });
  }

  @override
  Future<Result<void>> rename(int id, String firstName, String lastName) =>
      _change('rename:$id:$firstName $lastName', () {});

  @override
  Future<Result<void>> changeEmail(int id, String? email) =>
      _change('email:$id:$email', () {});

  @override
  Future<Result<void>> changeRole(int id, StaffRole role) =>
      _change('role:$id:${role.name}', () {});

  @override
  Future<Result<void>> resetPassword(int id, String temporaryPassword) =>
      _change('reset:$id', () {});

  @override
  Future<Result<void>> disable(int id) => _change('disable:$id', () {});

  @override
  Future<Result<void>> enable(int id) => _change('enable:$id', () {});

  @override
  Future<Result<void>> delete(int id) => _change('delete:$id', () {
    accounts = [
      for (final account in accounts)
        if (account.id != id) account,
    ];
  });

  Future<Result<void>> _change(String call, void Function() apply) async {
    calls.add(call);
    final failed = changeFailure;
    if (failed != null) {
      return Failed(failed);
    }
    apply();
    return const Success(null);
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
