import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/entities/planning.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/planning_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The answer to one step: whether it was saved, and the text to show.
typedef WorkOutcome = ({bool saved, String message});

/// The own shifts and rooms of a member of staff, and the trades around them
/// (MIL-060). The view model offers what the API allows; the API checks every
/// rule again, and its answer becomes the text of the outcome.
class MyWorkViewModel extends ChangeNotifier {
  /// Creates the view model for the member [session]. [now] is the clock.
  MyWorkViewModel({
    required this._planning,
    required this._session,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// How far ahead the own shifts are read.
  static const Duration horizon = Duration(days: 28);

  final PlanningRepository _planning;
  final StaffSession _session;
  final DateTime Function() _now;

  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;
  List<Shift> _shifts = const <Shift>[];
  List<ShiftTrade> _shiftTrades = const <ShiftTrade>[];
  RoomAssignmentOverview? _rooms;
  List<RoomTrade> _roomTrades = const <RoomTrade>[];

  /// True while the work is being read.
  bool get isLoading => _isLoading;

  /// True while a step is being saved.
  bool get isBusy => _isBusy;

  /// The text of a failure to read, or null.
  String? get errorMessage => _errorMessage;

  /// Whether the member has rooms, which only housekeepers do.
  bool get hasRooms => _session.role.hasRooms;

  /// False for a session from an API that does not name the account; the app
  /// cannot tell the own work apart then.
  bool get knowsMe => _session.staffId > 0;

  int get _me => _session.staffId;

  /// The own shifts that have not ended, by start.
  List<Shift> get myShifts {
    final now = _now();
    return [
      for (final shift in _shifts)
        if (shift.assigneeId == _me && shift.endsAt.isAfter(now)) shift,
    ];
  }

  /// The trade that is pending on [shift], or null.
  ShiftTrade? pendingTradeOn(Shift shift) {
    for (final trade in _shiftTrades) {
      if (trade.state.isPending &&
          (trade.shift.id == shift.id || trade.swapShift?.id == shift.id)) {
        return trade;
      }
    }
    return null;
  }

  /// Whether [shift] can be offered now: it is not within 24 hours and has no
  /// pending trade.
  bool canOffer(Shift shift) =>
      !shift.isClosedAt(_now()) && pendingTradeOn(shift) == null;

  /// The shifts of colleagues with the role of [shift] that it can be swapped
  /// for.
  List<Shift> swapCandidatesFor(Shift shift) {
    final now = _now();
    return [
      for (final other in _shifts)
        if (other.assigneeId != null &&
            other.assigneeId != _me &&
            other.role == shift.role &&
            !other.isClosedAt(now) &&
            pendingTradeOn(other) == null)
          other,
    ];
  }

  /// The swaps that colleagues offered the member and that wait for an answer.
  List<ShiftTrade> get swapsForMe => [
    for (final trade in _shiftTrades)
      if (trade.isSwap &&
          trade.takenById == _me &&
          trade.state == TradeState.open &&
          !trade.isClosed)
        trade,
  ];

  /// The shifts that colleagues give away and the member can take.
  List<ShiftTrade> get openShifts => [
    for (final trade in _shiftTrades)
      if (!trade.isSwap &&
          trade.offeredById != _me &&
          trade.state == TradeState.open &&
          !trade.isClosed)
        trade,
  ];

  /// The trades the member offered or took part in, apart from those waiting
  /// for the member's answer.
  List<ShiftTrade> get myShiftTrades => [
    for (final trade in _shiftTrades)
      if ((trade.offeredById == _me || trade.takenById == _me) &&
          !swapsForMe.contains(trade))
        trade,
  ];

  /// Whether the member offered [trade] and can still take it back.
  bool canWithdrawShift(ShiftTrade trade) =>
      trade.state.isPending && trade.offeredById == _me;

  /// Whether the member offered [trade] and can still take it back.
  bool canWithdrawRooms(RoomTrade trade) =>
      trade.state.isPending && trade.fromStaffId == _me;

  /// Whether the member offered [trade], rather than received it.
  bool offeredRooms(RoomTrade trade) => trade.fromStaffId == _me;

  /// The rooms of the member.
  List<RoomAssignment> get myRooms => _rooms?.roomsOf(_me) ?? const [];

  /// The fewest rooms a housekeeper keeps without a Manager's approval.
  int get minimumRooms => _rooms?.minimumRooms ?? 3;

  /// The other active housekeepers.
  List<Housekeeper> get colleagues => [
    for (final keeper in _rooms?.housekeepers ?? const <Housekeeper>[])
      if (keeper.id != _me) keeper,
  ];

  /// The rooms of a colleague.
  List<RoomAssignment> roomsOf(int staffId) =>
      _rooms?.roomsOf(staffId) ?? const [];

  /// The trades of rooms that colleagues offered the member and that wait for
  /// an answer.
  List<RoomTrade> get roomTradesForMe => [
    for (final trade in _roomTrades)
      if (trade.toStaffId == _me && trade.state == TradeState.open) trade,
  ];

  /// The other trades of rooms of the member.
  List<RoomTrade> get myRoomTrades => [
    for (final trade in _roomTrades)
      if (!roomTradesForMe.contains(trade)) trade,
  ];

  /// Whether giving [give] rooms and taking [take] rooms of [colleague] needs
  /// a Manager: it leaves one of the two with fewer rooms than before and
  /// fewer than the minimum. Only a hint; the API decides.
  bool needsApproval(int give, int take, Housekeeper colleague) {
    bool tooFew(int before, int after) =>
        after < before && after < minimumRooms;
    final mine = myRooms.length;
    return tooFew(mine, mine - give + take) ||
        tooFew(colleague.roomCount, colleague.roomCount + give - take);
  }

  /// Reads the shifts of the next weeks, the trades, and the rooms.
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await _read();
    _isLoading = false;
    notifyListeners();
  }

  /// Gives [shift] away to any colleague with its role.
  Future<WorkOutcome> giveAway(Shift shift) => _change(
    () => _planning.offerShift(shift.id),
    'Offered ${Strings.shiftWhen(shift.startsAt, shift.endsAt)}.',
  );

  /// Offers to swap [shift] for [other].
  Future<WorkOutcome> swap(Shift shift, Shift other) => _change(
    () => _planning.offerShift(shift.id, swapShiftId: other.id),
    'Asked ${other.assigneeName ?? ''} to swap.',
  );

  /// Takes one step of a trade of shifts.
  Future<WorkOutcome> stepShift(ShiftTrade trade, TradeStep step) => _change(
    () => _planning.stepShiftTrade(trade.id, step),
    Strings.tradeStepDone(step),
  );

  /// Gives [give] to [colleague], and asks for [take] in return.
  Future<WorkOutcome> offerRooms(
    Housekeeper colleague,
    List<int> give,
    List<int> take,
  ) => _change(
    () => _planning.offerRooms(colleague.id, give, take),
    'Sent to ${colleague.name}.',
  );

  /// Takes one step of a trade of rooms.
  Future<WorkOutcome> stepRooms(RoomTrade trade, TradeStep step) => _change(
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
    final now = _now();
    final shifts = await _planning.readShifts(now, now.add(horizon));
    final trades = await _planning.readShiftTrades();
    final rooms = hasRooms ? await _planning.readRoomAssignments() : null;
    final roomTrades = hasRooms ? await _planning.readRoomTrades() : null;

    String? failure;
    void take<T>(Result<T>? result, void Function(T value) keep) {
      switch (result) {
        case Success(:final value):
          keep(value);
        case Failed(failure: final ApiFailure problem):
          failure ??= Strings.planningFailure(problem);
        case null:
          break;
      }
    }

    take(shifts, (value) => _shifts = value);
    take(trades, (value) => _shiftTrades = value);
    take(rooms, (value) => _rooms = value);
    take(roomTrades, (value) => _roomTrades = value);
    _errorMessage = failure;
  }
}
