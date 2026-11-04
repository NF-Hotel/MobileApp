import 'package:mobil_application/domain/entities/staff_session.dart';

/// Where a trade of rooms or of shifts is (MIL-060).
enum TradeState {
  /// Offered; waiting for the colleague.
  open,

  /// The colleague agreed; waiting for a Manager.
  awaitingApproval,

  /// Carried out.
  done,

  /// The colleague said no.
  declined,

  /// A Manager said no.
  rejected,

  /// Taken back by the member who offered it.
  withdrawn,

  /// Called off: a room or a shift changed hands in another way meanwhile.
  cancelled;

  /// True while the trade waits for a colleague or a Manager.
  bool get isPending => this == open || this == awaitingApproval;
}

/// A shift (MIL-060).
class Shift {
  /// Creates a shift.
  const Shift({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.role,
    this.assigneeId,
    this.assigneeName,
  });

  /// The key.
  final int id;

  /// When it starts.
  final DateTime startsAt;

  /// When it ends.
  final DateTime endsAt;

  /// The role it needs.
  final StaffRole role;

  /// Who works it, or null.
  final int? assigneeId;

  /// The name of who works it, or null.
  final String? assigneeName;

  /// Whether it can no longer be traded at [now]: within 24 hours of the
  /// start. The API decides; this only hides buttons that would be refused.
  bool isClosedAt(DateTime now) =>
      !now.isBefore(startsAt.subtract(const Duration(hours: 24)));
}

/// A shift given away, or a swap of shifts (MIL-060).
class ShiftTrade {
  /// Creates a trade.
  const ShiftTrade({
    required this.id,
    required this.shift,
    required this.offeredById,
    required this.offeredByName,
    required this.state,
    required this.isClosed,
    this.swapShift,
    this.takenById,
    this.takenByName,
  });

  /// The key.
  final int id;

  /// The shift offered.
  final Shift shift;

  /// The shift asked for in a swap, or null when the shift is given away.
  final Shift? swapShift;

  /// Who offered it.
  final int offeredById;

  /// The name of who offered it.
  final String offeredByName;

  /// The colleague who took it, or who is asked to accept the swap.
  final int? takenById;

  /// The name of that colleague.
  final String? takenByName;

  /// Where it is.
  final TradeState state;

  /// True when a shift of it starts within 24 hours.
  final bool isClosed;

  /// True for a swap.
  bool get isSwap => swapShift != null;
}

/// A room and its housekeeper (MIL-060).
class RoomAssignment {
  /// Creates the assignment.
  const RoomAssignment({
    required this.roomId,
    required this.roomNumber,
    required this.floor,
    this.staffId,
    this.staffName,
  });

  /// The room.
  final int roomId;

  /// The number on the door.
  final String roomNumber;

  /// The floor.
  final int floor;

  /// The housekeeper, or null.
  final int? staffId;

  /// The name of the housekeeper, or null.
  final String? staffName;
}

/// An active housekeeper and how many rooms the housekeeper has.
class Housekeeper {
  /// Creates the housekeeper.
  const Housekeeper({
    required this.id,
    required this.name,
    required this.roomCount,
  });

  /// The account.
  final int id;

  /// The name.
  final String name;

  /// How many rooms are assigned.
  final int roomCount;
}

/// Every room with its housekeeper, and every active housekeeper.
class RoomAssignmentOverview {
  /// Creates the overview.
  const RoomAssignmentOverview({
    required this.rooms,
    required this.housekeepers,
    required this.minimumRooms,
  });

  /// The rooms, by floor and number.
  final List<RoomAssignment> rooms;

  /// The active housekeepers.
  final List<Housekeeper> housekeepers;

  /// The fewest rooms a housekeeper keeps without a Manager's approval.
  final int minimumRooms;

  /// The rooms of one housekeeper.
  List<RoomAssignment> roomsOf(int staffId) => [
    for (final room in rooms)
      if (room.staffId == staffId) room,
  ];
}

/// A room in a trade.
class TradedRoom {
  /// Creates the room.
  const TradedRoom({required this.roomId, required this.roomNumber});

  /// The room.
  final int roomId;

  /// The number on the door.
  final String roomNumber;
}

/// A trade of rooms between two housekeepers (MIL-060).
class RoomTrade {
  /// Creates the trade.
  const RoomTrade({
    required this.id,
    required this.fromStaffId,
    required this.fromName,
    required this.toStaffId,
    required this.toName,
    required this.give,
    required this.take,
    required this.state,
  });

  /// The key.
  final int id;

  /// Who offered it.
  final int fromStaffId;

  /// The name of who offered it.
  final String fromName;

  /// The colleague it is offered to.
  final int toStaffId;

  /// The name of the colleague.
  final String toName;

  /// The rooms that go to the colleague.
  final List<TradedRoom> give;

  /// The rooms that come back; empty for a gift.
  final List<TradedRoom> take;

  /// Where it is.
  final TradeState state;
}
