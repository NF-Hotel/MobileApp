import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
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
