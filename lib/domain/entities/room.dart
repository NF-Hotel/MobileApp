/// The cleaning state of a room. The API keeps it by the name of the value.
enum RoomStatus {
  /// Clean and ready.
  clean,

  /// Waiting for a full cleaning.
  needsCleaning,

  /// Waiting for the daily cleaning.
  dailyCleaning,

  /// Something in the room needs fixing.
  needsMaintenance,
}

/// A room of the hotel, as the API reports it.
class Room {
  /// Creates a room.
  const Room({
    required this.number,
    required this.name,
    required this.status,
    this.cleaners = const <String>[],
  });

  /// The key of the room in the API; notes and routes use it.
  final int number;

  /// What the staff call the room.
  final String name;

  /// Its cleaning state.
  final RoomStatus status;

  /// The names of the staff assigned to it.
  final List<String> cleaners;

  /// The same room with another [status].
  Room withStatus(RoomStatus status) =>
      Room(number: number, name: name, status: status, cleaners: cleaners);
}

/// A note on a room, for example something a cleaner found.
class RoomNote {
  /// Creates a note.
  const RoomNote({
    required this.id,
    required this.body,
    required this.createdBy,
    required this.createdAt,
    this.resolvedBy,
    this.resolvedAt,
  });

  /// The key of the note.
  final int id;

  /// What it says.
  final String body;

  /// The email of the author.
  final String createdBy;

  /// When it was written.
  final DateTime createdAt;

  /// The email of whoever ticked it off, or null.
  final String? resolvedBy;

  /// When it was ticked off, or null.
  final DateTime? resolvedAt;

  /// True once someone has ticked it off.
  bool get isResolved => resolvedAt != null;
}
