import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// What the room overview is doing.
enum RoomOverviewState {
  /// Reading the rooms.
  loading,

  /// The rooms are shown.
  ready,

  /// Reading failed; [RoomOverviewViewModel.errorMessage] says why.
  error,
}

/// The state of the room overview: all rooms, in the order of their numbers.
class RoomOverviewViewModel extends ChangeNotifier {
  /// Creates the view model.
  RoomOverviewViewModel({required this._rooms});

  final RoomRepository _rooms;

  RoomOverviewState _state = RoomOverviewState.loading;
  List<Room> _list = const <Room>[];
  String? _errorMessage;

  /// What the overview is doing.
  RoomOverviewState get state => _state;

  /// The rooms, by floor and then by number.
  List<Room> get rooms => _list;

  /// The text of the failure when [state] is [RoomOverviewState.error].
  String? get errorMessage => _errorMessage;

  /// Reads the rooms again.
  Future<void> load() async {
    _state = RoomOverviewState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _rooms.readAll();
    switch (result) {
      case Success(:final value):
        _list = [...value]..sort(_byFloorThenNumber);
        _state = RoomOverviewState.ready;
      case Failed(:final failure):
        _errorMessage = Strings.failure(failure);
        _state = RoomOverviewState.error;
    }
    notifyListeners();
  }

  static int _byFloorThenNumber(Room a, Room b) {
    final byFloor = a.floor.compareTo(b.floor);
    return byFloor != 0 ? byFloor : a.roomNumber.compareTo(b.roomNumber);
  }
}
