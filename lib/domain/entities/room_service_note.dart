/// A note on a room that says what service it needs, with who wrote it and who
/// marked it as done, as the API reports it.
///
/// A note is open until somebody marks it as done. For five minutes after that
/// anybody can undo the mark; then the note is in the history, and only a
/// Manager can open it again. The API holds that rule and its clock: the app
/// shows what it answers and never works out the five minutes itself, because
/// the clock of a phone can be wrong.
class RoomServiceNote {
  /// Creates a note.
  const RoomServiceNote({
    required this.id,
    required this.roomId,
    required this.text,
    required this.writtenBy,
    required this.writtenAt,
    this.doneBy,
    this.doneAt,
    this.undoableUntil,
  });

  /// The key of the note.
  final int id;

  /// The room the note is about.
  final int roomId;

  /// What the room needs.
  final String text;

  /// The user name of the member of staff who wrote it.
  final String writtenBy;

  /// When it was written.
  final DateTime writtenAt;

  /// The user name of the member of staff who marked it as done, or null while
  /// it is open.
  final String? doneBy;

  /// When it was marked as done, or null while it is open.
  final DateTime? doneAt;

  /// The moment it goes to the history, or null while it is open.
  final DateTime? undoableUntil;

  /// True when the note is marked as done.
  bool get isDone => doneAt != null;
}
