import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The state of one room: its cleaning state and its notes.
class RoomViewModel extends ChangeNotifier {
  /// Creates the view model for [room], seen by [viewer]. [now] is the clock,
  /// so a test can fix the time.
  RoomViewModel({
    required this._rooms,
    required this._room,
    required this._viewer,
    this._now = DateTime.now,
  });

  /// How long the author may delete a note, and the one who ticked it off may
  /// tick it on again. The API enforces it; the app only hides the buttons.
  static const Duration undoWindow = Duration(minutes: 10);

  final RoomRepository _rooms;
  final StaffSession _viewer;
  final DateTime Function() _now;
  Room _room;
  List<RoomNote> _notes = const <RoomNote>[];
  bool _isBusy = false;
  String? _errorMessage;

  /// The room as last changed.
  Room get room => _room;

  /// The notes, newest first.
  List<RoomNote> get notes => _notes;

  /// True while the API is being called.
  bool get isBusy => _isBusy;

  /// The text of the last failure, or null.
  String? get errorMessage => _errorMessage;

  /// Whether the viewer may delete [note].
  bool canDelete(RoomNote note) =>
      _viewer.isAdmin ||
      (note.createdBy == _viewer.email && _isRecent(note.createdAt));

  /// Whether the viewer may tick [note] off, or on again.
  bool canToggle(RoomNote note) {
    final resolvedAt = note.resolvedAt;
    return resolvedAt == null ||
        _viewer.isAdmin ||
        (note.resolvedBy == _viewer.email && _isRecent(resolvedAt));
  }

  bool _isRecent(DateTime time) => _now().difference(time) < undoWindow;

  /// Reads the notes again. True when it worked; the same for the others.
  Future<bool> load() => _run(_readNotes);

  /// Sets the cleaning state.
  Future<bool> setStatus(RoomStatus status) => _run(() async {
    final result = await _rooms.setStatus(_room.number, status);
    if (result case Failed(:final failure)) {
      return failure;
    }
    _room = _room.withStatus(status);
    return null;
  });

  /// Adds a note; an empty one is not sent.
  Future<bool> addNote(String body) async => body.trim().isNotEmpty
      ? _changeNotes(() => _rooms.addNote(_room.number, body.trim()))
      : false;

  /// Ticks [note] off, or on again.
  Future<bool> setResolved(RoomNote note, bool resolved) =>
      _changeNotes(() => _rooms.setResolved(_room.number, note.id, resolved));

  /// Deletes [note].
  Future<bool> deleteNote(RoomNote note) =>
      _changeNotes(() => _rooms.deleteNote(_room.number, note.id));

  /// A change to the notes, then the notes as the API has them now.
  Future<bool> _changeNotes(Future<Result<void>> Function() change) =>
      _run(() async {
        final result = await change();
        return result is Failed<void> ? result.failure : _readNotes();
      });

  Future<ApiFailure?> _readNotes() async {
    switch (await _rooms.readNotes(_room.number)) {
      case Success(:final value):
        _notes = value;
        return null;
      case Failed(:final failure):
        return failure;
    }
  }

  Future<bool> _run(Future<ApiFailure?> Function() call) async {
    if (_isBusy) {
      return false;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    final failure = await call();
    _errorMessage = failure == null ? null : Strings.failure(failure);

    _isBusy = false;
    notifyListeners();
    return failure == null;
  }
}
