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

/// The state of the room overview: the rooms the member may see, in the order
/// the API gives them.
class RoomOverviewViewModel extends ChangeNotifier {
  /// Creates the view model.
  RoomOverviewViewModel({required this._rooms});

  final RoomRepository _rooms;

  RoomOverviewState _state = RoomOverviewState.loading;
  List<Room> _list = const <Room>[];
  String? _errorMessage;

  /// What the overview is doing.
  RoomOverviewState get state => _state;

  /// The rooms.
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
        _list = value;
        _state = RoomOverviewState.ready;
      case Failed(:final failure):
        _errorMessage = Strings.failure(failure);
        _state = RoomOverviewState.error;
    }
    notifyListeners();
  }
}
