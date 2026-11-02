import 'package:flutter/foundation.dart';

import 'package:mobil_application/domain/entities/room_service_note.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/room_service_note_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The service notes of one room: the current ones and its history.
///
/// It holds no rule about the five minutes. Which notes are current comes from
/// the API, which also refuses an undo that came too late; that answer becomes a
/// message here, and the notes are read again.
class RoomServiceNotesViewModel extends ChangeNotifier {
  /// Creates the view model of the room [roomId] for a member of staff with the
  /// role [role].
  RoomServiceNotesViewModel({
    required this._notes,
    required this._roomId,
    required this._role,
  });

  final RoomServiceNoteRepository _notes;
  final int _roomId;
  final StaffRole _role;

  List<RoomServiceNote> _current = const <RoomServiceNote>[];
  List<RoomServiceNote> _history = const <RoomServiceNote>[];
  bool _isBusy = false;
  bool _isReadingHistory = false;
  bool _hasReadHistory = false;
  String? _errorMessage;
  int _currentReads = 0;

  /// The notes of the room that are not in the history, oldest first.
  List<RoomServiceNote> get notes => _current;

  /// The finished service of the room, most recently done first.
  List<RoomServiceNote> get history => _history;

  /// True while the API is being called for a change or at the first read.
  bool get isBusy => _isBusy;

  /// True while the history is being read.
  bool get isReadingHistory => _isReadingHistory;

  /// True once the history has been read, so that an empty one can be told.
  bool get hasReadHistory => _hasReadHistory;

  /// The text of the last failure, or null.
  String? get errorMessage => _errorMessage;

  /// Whether the member of staff may write a note.
  bool get canWrite => _role.canWriteServiceNotes;

  /// Whether the member of staff may take a note back from the history.
  bool get canReopen => _role.canReopenServiceNotes;

  /// Reads the current notes and shows a failure.
  Future<void> load() async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    _errorMessage = await _readCurrent();

    _isBusy = false;
    notifyListeners();
  }

  /// Reads the current notes while the screen stays open, so that a mark moves to
  /// the history on time and the notes of the others show up. It leaves the
  /// message alone: a failed round tries again by itself, and the answer to a tap
  /// must stay on the screen. It stands aside while another call is in progress.
  Future<void> refresh() async {
    if (_isBusy) {
      return;
    }
    await _readCurrent();
    notifyListeners();
  }

  /// Sends [text] as a note, which also reports that the room needs service.
  /// Returns true if the note was written, so the room has to be read again.
  Future<bool> report(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return Future<bool>.value(false);
    }
    return _change(() => _notes.create(_roomId, trimmed));
  }

  /// Marks a current note as done, or undoes the mark.
  Future<void> toggleDone(RoomServiceNote note) => _change(
    () => note.isDone ? _notes.undoDone(note.id) : _notes.markDone(note.id),
  );

  /// Takes a note back from the history. Returns true if the note is open again,
  /// so the room has to be read again.
  Future<bool> reopen(RoomServiceNote note) =>
      _change(() => _notes.reopen(note.id), readHistory: true);

  /// Reads the history of the room. It does not wait for other calls, so that a
  /// history opened during the first read of the notes is not left empty.
  Future<void> loadHistory() async {
    if (_isReadingHistory) {
      return;
    }
    _isReadingHistory = true;
    _errorMessage = null;
    notifyListeners();

    _errorMessage = await _readHistory();

    _isReadingHistory = false;
    notifyListeners();
  }

  /// Runs one change and shows its answer. The notes are read again either way,
  /// because a refused change means that the screen is out of date.
  Future<bool> _change(
    Future<Result<RoomServiceNote>> Function() call, {
    bool readHistory = false,
  }) async {
    if (_isBusy) {
      return false;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    final result = await call();
    final succeeded = result is Success<RoomServiceNote>;
    if (result is Failed<RoomServiceNote>) {
      _errorMessage = Strings.serviceNoteFailure(result.failure);
    }

    final readFailure = await _readCurrent();
    final historyFailure = readHistory ? await _readHistory() : null;
    _errorMessage ??= readFailure ?? historyFailure;

    _isBusy = false;
    notifyListeners();
    return succeeded;
  }

  /// Reads the current notes of the room and returns the text of a failure. Only
  /// the last read counts: a refresh that was under way when a change started
  /// answers with the state from before the change.
  Future<String?> _readCurrent() async {
    final read = ++_currentReads;
    final result = await _notes.readCurrent();
    switch (result) {
      case Success(:final value):
        if (read == _currentReads) {
          _current = [
            for (final note in value)
              if (note.roomId == _roomId) note,
          ];
        }
        return null;
      case Failed(:final failure):
        return Strings.serviceNoteFailure(failure);
    }
  }

  Future<String?> _readHistory() async {
    final result = await _notes.readHistory(_roomId);
    switch (result) {
      case Success(:final value):
        _history = value;
        _hasReadHistory = true;
        return null;
      case Failed(:final failure):
        return Strings.serviceNoteFailure(failure);
    }
  }
}
