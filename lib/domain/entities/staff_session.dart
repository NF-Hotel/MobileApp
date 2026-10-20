/// The role of a member of staff; it decides what the API lets them do.
enum StaffRole {
  /// Works with bookings and guests, reads rooms.
  receptionist,

  /// Everything.
  manager,

  /// Reads rooms and updates their cleaning and service status.
  housekeeping,
}

/// A signed-in member of staff and the token the API gave them.
class StaffSession {
  /// Creates a session.
  const StaffSession({
    required this.token,
    required this.expiresAt,
    required this.userName,
    required this.role,
  });

  /// The staff token; sent in `X-Staff-Token`. A secret: never log it.
  final String token;

  /// When the token stops being accepted.
  final DateTime expiresAt;

  /// The user name as the API knows it.
  final String userName;

  /// The role.
  final StaffRole role;

  /// Tells whether the token is no longer valid at [now].
  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);
}
