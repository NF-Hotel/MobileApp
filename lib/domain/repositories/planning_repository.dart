import 'package:mobil_application/domain/entities/planning.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';

/// A step of a trade that the API offers below the trade.
enum TradeStep {
  /// A colleague takes a shift that is given away.
  take,

  /// The colleague accepts.
  accept,

  /// The colleague declines.
  decline,

  /// The member who offered it takes it back.
  withdraw,

  /// A Manager approves.
  approve,

  /// A Manager rejects.
  reject,
}

/// The shifts, the room assignments and their trades through the API
/// (MIL-060). The API checks the role and every rule again.
abstract interface class PlanningRepository {
  /// The shifts that overlap a period: every shift for a Manager, the shifts
  /// of the own role for the others.
  Future<Result<List<Shift>>> readShifts(DateTime from, DateTime to);

  /// A Manager plans a shift.
  Future<Result<Shift>> createShift(
    DateTime startsAt,
    DateTime endsAt,
    StaffRole role,
    int? assigneeId,
  );

  /// A Manager changes a shift.
  Future<Result<Shift>> updateShift(
    int id,
    DateTime startsAt,
    DateTime endsAt,
    StaffRole role,
    int? assigneeId,
  );

  /// A Manager deletes a shift.
  Future<Result<void>> deleteShift(int id);

  /// The trades of shifts the caller can act on or follow.
  Future<Result<List<ShiftTrade>>> readShiftTrades();

  /// Gives an own shift away, or offers it for [swapShiftId].
  Future<Result<ShiftTrade>> offerShift(int shiftId, {int? swapShiftId});

  /// Takes one step of a trade of shifts.
  Future<Result<ShiftTrade>> stepShiftTrade(int id, TradeStep step);

  /// Every room with its housekeeper, and every active housekeeper.
  Future<Result<RoomAssignmentOverview>> readRoomAssignments();

  /// A Manager gives a room to a housekeeper, or to nobody.
  Future<Result<void>> assignRoom(int roomId, int? staffId);

  /// The trades of rooms of the caller, and for a Manager those that wait.
  Future<Result<List<RoomTrade>>> readRoomTrades();

  /// Gives rooms to a colleague, or trades them for rooms of the colleague.
  Future<Result<RoomTrade>> offerRooms(
    int toStaffId,
    List<int> giveRoomIds,
    List<int> takeRoomIds,
  );

  /// Takes one step of a trade of rooms; [TradeStep.take] is not one.
  Future<Result<RoomTrade>> stepRoomTrade(int id, TradeStep step);
}
