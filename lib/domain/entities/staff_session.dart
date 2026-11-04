/// The role of a member of staff; it decides what the API lets them do.
enum StaffRole {
  /// Works with bookings and guests, reads rooms.
  receptionist,

  /// Everything.
  manager,

  /// Reads rooms and updates their cleaning and service status.
  housekeeping;

  /// Whether the role may write a service note on a room. Only what the app
  /// offers: the API refuses everybody else as well.
  bool get canWriteServiceNotes => this != StaffRole.receptionist;

  /// Whether the role may take a service note back from the history. Only what
  /// the app offers: the API refuses everybody else as well.
  bool get canReopenServiceNotes => this == StaffRole.manager;

  /// Whether the role may manage the staff accounts (MIL-059). Only what the
  /// app offers: the API refuses everybody else as well.
  bool get canManageStaff => this == StaffRole.manager;
}

/// A signed-in member of staff and the token the API gave them.
class StaffSession {
  /// Creates a session.
  const StaffSession({
    required this.token,
    required this.expiresAt,
    required this.userName,
    required this.role,
    this.mustChangePassword = false,
    this.firstName,
    this.lastName,
  });

  /// The staff token; sent in `X-Staff-Token`. A secret: never log it.
  final String token;

  /// When the token stops being accepted.
  final DateTime expiresAt;

  /// The user name as the API knows it.
  final String userName;

  /// The role.
  final StaffRole role;

  /// True when the member must choose a new password before anything else; the
  /// API refuses every other call until then (ADR-0017).
  final bool mustChangePassword;

  /// The first name, or null while the account has no name (MIL-059).
  final String? firstName;

  /// The last name, or null while the account has no name (MIL-059).
  final String? lastName;

  /// True when the account has a first and a last name.
  bool get hasName => firstName != null && lastName != null;

  /// The name to show: the first and the last name, or the user name while the
  /// account has none.
  String get displayName => hasName ? '$firstName $lastName' : userName;

  /// Tells whether the token is no longer valid at [now].
  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);
}
