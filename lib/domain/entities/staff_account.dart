import 'package:mobil_application/domain/entities/staff_session.dart';

/// A staff account as a Manager sees it in the administration (MIL-059). It
/// never holds the password or its hash.
class StaffAccount {
  /// Creates an account.
  const StaffAccount({
    required this.id,
    required this.userName,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    this.firstName,
    this.lastName,
    this.email,
  });

  /// The key of the account.
  final int id;

  /// The name the member signs in with.
  final String userName;

  /// The role.
  final StaffRole role;

  /// False when the account is disabled.
  final bool isActive;

  /// True when the member has to choose a new password at the next sign-in.
  final bool mustChangePassword;

  /// The first name, or null while the account has no name.
  final String? firstName;

  /// The last name, or null while the account has no name.
  final String? lastName;

  /// The e-mail address, or null. It is for reaching the member, not for the
  /// sign-in.
  final String? email;

  /// True when the account has a first and a last name.
  bool get hasName => firstName != null && lastName != null;

  /// The name to show: the first and the last name, or the user name while the
  /// account has none.
  String get displayName => hasName ? '$firstName $lastName' : userName;
}

/// The fields of a new account (MIL-059). The member must change the temporary
/// password at the first sign-in.
class NewStaffAccount {
  /// Creates the fields.
  const NewStaffAccount({
    required this.firstName,
    required this.lastName,
    required this.userName,
    required this.temporaryPassword,
    required this.role,
    this.email,
  });

  /// The first name.
  final String firstName;

  /// The last name.
  final String lastName;

  /// The name the member signs in with.
  final String userName;

  /// The password the member signs in with the first time. A secret: never
  /// log it.
  final String temporaryPassword;

  /// The role.
  final StaffRole role;

  /// The e-mail address, or null.
  final String? email;
}
