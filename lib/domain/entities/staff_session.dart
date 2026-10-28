/// The role of a member of staff; it decides what the API lets them do.
enum StaffRole {
  /// Everything, also the accounts and the rooms themselves.
  admin,

  /// Sees and changes only the rooms they are assigned to.
  cleaner,

  /// Sees and changes every room.
  technician,
}

/// A signed-in member of staff, as read from the token the API gave them.
class StaffSession {
  /// Creates a session.
  const StaffSession({
    required this.token,
    required this.expiresAt,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  /// The access token (a JWT); sent as a bearer token. A secret: never log it.
  final String token;

  /// When the token stops being accepted.
  final DateTime expiresAt;

  /// The email the member signed in with.
  final String email;

  /// The first name; empty until it is set.
  final String firstName;

  /// The last name; empty until it is set.
  final String lastName;

  /// The role.
  final StaffRole role;

  /// False for a new account: it sets its name once before anything else.
  bool get hasName => firstName.trim().isNotEmpty && lastName.trim().isNotEmpty;

  /// The name to show, or the email while there is no name.
  String get displayName => hasName ? '$firstName $lastName' : email;

  /// True for an administrator.
  bool get isAdmin => role == StaffRole.admin;

  /// Tells whether the token is no longer valid at [now].
  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);
}
