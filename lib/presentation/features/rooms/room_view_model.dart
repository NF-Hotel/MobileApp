import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The state of one room and the cleaning and service actions on it.
class RoomViewModel extends ChangeNotifier {
  /// Creates the view model for [room], which is shown at once and refreshed by
  /// [load].
  RoomViewModel({required this._rooms, required this._room});

  final RoomRepository _rooms;
  Room _room;
  bool _isBusy = false;
  String? _errorMessage;

  /// The room as last read.
  Room get room => _room;

  /// True while the API is being called.
  bool get isBusy => _isBusy;

  /// The text of the last failure, or null.
  String? get errorMessage => _errorMessage;

  /// The actions that the room allows now, in the order of a cleaning round.
  List<RoomAction> get actions => [
    for (final action in RoomAction.values)
      if (_room.actions.allows(action)) action,
  ];

  /// Reads the room again.
  Future<void> load() => _run(() => _rooms.read(_room.roomId));

  /// Does [action]. [requiresCleaning] matters for completing a service only.
  Future<void> perform(RoomAction action, {bool requiresCleaning = false}) =>
      _run(
        () => _rooms.perform(
          _room.roomId,
          action,
          requiresCleaning: requiresCleaning,
        ),
      );

  Future<void> _run(Future<Result<Room>> Function() call) async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    final result = await call();
    switch (result) {
      case Success(:final value):
        _room = value;
      case Failed(:final failure):
        _errorMessage = Strings.failure(failure);
    }

    _isBusy = false;
    notifyListeners();
  }
}
