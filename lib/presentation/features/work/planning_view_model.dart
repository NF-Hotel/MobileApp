import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import 'package:mobil_application/domain/entities/planning.dart';
import 'package:mobil_application/domain/entities/staff_account.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/planning_repository.dart';
import 'package:mobil_application/domain/repositories/staff_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/features/work/my_work_view_model.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The planning of a Manager (MIL-060): a week of shifts, the rooms of the
/// housekeepers, and the trades that wait for approval. The API checks every
/// rule again, and its answer becomes the text of the outcome.
class PlanningViewModel extends ChangeNotifier {
  /// Creates the view model. [now] is the clock.
  PlanningViewModel({
    required this._planning,
    required this._staff,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    final today = _now();
    _weekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
  }

  final PlanningRepository _planning;
  final StaffRepository _staff;
  final DateTime Function() _now;

  late DateTime _weekStart;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;
  List<Shift> _shifts = const <Shift>[];
  List<StaffAccount> _accounts = const <StaffAccount>[];
  List<ShiftTrade> _shiftTrades = const <ShiftTrade>[];
  RoomAssignmentOverview? _rooms;
  List<RoomTrade> _roomTrades = const <RoomTrade>[];

  /// The Monday of the week shown, at midnight.
  DateTime get weekStart => _weekStart;

  /// The days of the week shown.
  List<DateTime> get days => [
    for (var day = 0; day < 7; day++)
      DateTime(_weekStart.year, _weekStart.month, _weekStart.day + day),
  ];

  /// True while the planning is being read.
  bool get isLoading => _isLoading;

  /// True while a change is being saved.
  bool get isBusy => _isBusy;

  /// The text of a failure to read, or null.
  String? get errorMessage => _errorMessage;

  /// The rooms with their housekeepers, or null before the first read.
  RoomAssignmentOverview? get rooms => _rooms;

  /// The shifts that a colleague agreed to and that wait for approval.
  List<ShiftTrade> get shiftApprovals => [
    for (final trade in _shiftTrades)
      if (trade.state == TradeState.awaitingApproval) trade,
  ];

  /// The trades of rooms that wait for approval.
  List<RoomTrade> get roomApprovals => [
    for (final trade in _roomTrades)
      if (trade.state == TradeState.awaitingApproval) trade,
  ];

  /// How many trades wait for approval.
  int get approvalCount => shiftApprovals.length + roomApprovals.length;

  /// The shifts that start on [day], by start.
  List<Shift> shiftsOn(DateTime day) => [
    for (final shift in _shifts)
      if (shift.startsAt.year == day.year &&
          shift.startsAt.month == day.month &&
          shift.startsAt.day == day.day)
        shift,
  ];

  /// The active accounts with [role], who can work a shift that needs it.
  List<StaffAccount> staffFor(StaffRole role) => [
    for (final account in _accounts)
      if (account.isActive && account.role == role) account,
  ];

  /// Whether [keeper] has fewer rooms than the minimum.
  bool isBelowMinimum(Housekeeper keeper) =>
      keeper.roomCount < (_rooms?.minimumRooms ?? 0);

  /// Reads the week, the staff, the rooms and the trades.
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await _read();
    _isLoading = false;
    notifyListeners();
  }

  /// Shows the week before.
  Future<void> previousWeek() {
    _weekStart = DateTime(
      _weekStart.year,
      _weekStart.month,
      _weekStart.day - 7,
    );
    return load();
  }

  /// Shows the week after.
  Future<void> nextWeek() {
    _weekStart = DateTime(
      _weekStart.year,
      _weekStart.month,
      _weekStart.day + 7,
    );
    return load();
  }

  /// Plans a shift on [day] from [start] to [end], or changes [existing]. An
  /// end before the start is on the next day.
  Future<WorkOutcome> saveShift({
    required DateTime day,
    required TimeOfDay start,
    required TimeOfDay end,
    required StaffRole role,
    int? assigneeId,
    Shift? existing,
  }) {
    final startsAt = DateTime(
      day.year,
      day.month,
      day.day,
      start.hour,
      start.minute,
    );
    var endsAt = DateTime(day.year, day.month, day.day, end.hour, end.minute);
    if (!endsAt.isAfter(startsAt)) {
      endsAt = DateTime(day.year, day.month, day.day + 1, end.hour, end.minute);
    }
    return _change(
      () => existing == null
          ? _planning.createShift(startsAt, endsAt, role, assigneeId)
          : _planning.updateShift(
              existing.id,
              startsAt,
              endsAt,
              role,
              assigneeId,
            ),
      existing == null ? 'Planned the shift.' : 'Saved the shift.',
    );
  }

  /// Deletes [shift] and its trades.
  Future<WorkOutcome> deleteShift(Shift shift) =>
      _change(() => _planning.deleteShift(shift.id), 'Deleted the shift.');

  /// Gives [room] to the housekeeper [staffId], or to nobody.
  Future<WorkOutcome> assignRoom(RoomAssignment room, int? staffId) => _change(
    () => _planning.assignRoom(room.roomId, staffId),
    staffId == null
        ? 'Room ${room.roomNumber} has no housekeeper now.'
        : 'Assigned room ${room.roomNumber}.',
  );

  /// Approves or rejects a trade of shifts.
  Future<WorkOutcome> decideShift(ShiftTrade trade, TradeStep step) => _change(
    () => _planning.stepShiftTrade(trade.id, step),
    Strings.tradeStepDone(step),
  );

  /// Approves or rejects a trade of rooms.
  Future<WorkOutcome> decideRooms(RoomTrade trade, TradeStep step) => _change(
    () => _planning.stepRoomTrade(trade.id, step),
    Strings.tradeStepDone(step),
  );

  Future<WorkOutcome> _change<T>(
    Future<Result<T>> Function() call,
    String success,
  ) async {
    if (_isBusy) {
      return (saved: false, message: '');
    }
    _isBusy = true;
    notifyListeners();

    final result = await call();
    final outcome = switch (result) {
      Success() => (saved: true, message: success),
      Failed(:final failure) => (
        saved: false,
        message: Strings.planningFailure(failure),
      ),
    };
    await _read();

    _isBusy = false;
    notifyListeners();
    return outcome;
  }

  Future<void> _read() async {
    final end = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7);
    final shifts = await _planning.readShifts(_weekStart, end);
    final accounts = await _staff.readAll();
    final shiftTrades = await _planning.readShiftTrades();
    final rooms = await _planning.readRoomAssignments();
    final roomTrades = await _planning.readRoomTrades();

    String? problem;
    void take<T>(Result<T> result, void Function(T value) keep) {
      switch (result) {
        case Success(:final value):
          keep(value);
        case Failed(:final failure):
          problem ??= Strings.planningFailure(failure);
      }
    }

    take(shifts, (value) => _shifts = value);
    take(accounts, (value) => _accounts = value);
    take(shiftTrades, (value) => _shiftTrades = value);
    take(rooms, (value) => _rooms = value);
    take(roomTrades, (value) => _roomTrades = value);
    _errorMessage = problem;
  }
}
