import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';

/// The texts the screens show, in one place. English only for now; moving them
/// to ARB files with `flutter gen-l10n` is a later step.
abstract final class Strings {
  static const String appTitle = 'NF Hotel';
  static const String signInTitle = 'Sign in';
  static const String userName = 'User name';
  static const String password = 'Password';
  static const String signInButton = 'Sign in';
  static const String signOut = 'Sign out';
  static const String userNameRequired = 'Enter your user name';
  static const String passwordRequired = 'Enter your password';
  static const String roomsTitle = 'Rooms';
  static const String refresh = 'Refresh';
  static const String noRooms = 'There are no rooms.';
  static const String retry = 'Try again';
  static const String roomTitle = 'Room';
  static const String cleaningFollows = 'Does cleaning follow the service?';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String cancel = 'Cancel';
  static const String nothingToDo = 'Nothing to do with this room now.';

  /// The text of a failure, without a code or a stack trace.
  static String failure(ApiFailure failure) => switch (failure.kind) {
    FailureKind.invalidCredentials => 'The user name or the password is wrong.',
    FailureKind.tooManyAttempts =>
      'Too many failed attempts. Wait fifteen minutes and try again.',
    FailureKind.unauthorized => 'Your session has ended. Sign in again.',
    FailureKind.forbidden => 'Your role may not do that.',
    FailureKind.notFound => 'The room was not found.',
    FailureKind.rejected => 'That is not possible with the room now.',
    FailureKind.network =>
      'The hotel system cannot be reached. Check the connection and try '
          'again.',
    FailureKind.server => 'Something went wrong. Try again later.',
  };

  /// The name of a role.
  static String role(StaffRole role) => switch (role) {
    StaffRole.receptionist => 'Receptionist',
    StaffRole.manager => 'Manager',
    StaffRole.housekeeping => 'Housekeeping',
  };

  /// The state of a room in housekeeping.
  static String housekeeping(HousekeepingStatus status) => switch (status) {
    HousekeepingStatus.clean => 'Clean',
    HousekeepingStatus.dailyCleaningDue => 'Daily cleaning due',
    HousekeepingStatus.departureCleaningDue => 'Departure cleaning due',
    HousekeepingStatus.cleaningInProgress => 'Being cleaned',
    HousekeepingStatus.serviceRequired => 'Service needed',
    HousekeepingStatus.serviceInProgress => 'Being serviced',
  };

  /// Whether a room can be let.
  static String roomStatus(RoomStatus status) => switch (status) {
    RoomStatus.available => 'In use',
    RoomStatus.outOfService => 'Out of service',
    RoomStatus.maintenance => 'Maintenance',
  };

  /// The size of a room.
  static String size(RoomSize size) => switch (size) {
    RoomSize.single => 'Single',
    RoomSize.double => 'Double',
    RoomSize.suite => 'Suite',
  };

  /// The label of the button for an action.
  static String action(RoomAction action) => switch (action) {
    RoomAction.markDailyCleaningDue => 'Mark daily cleaning due',
    RoomAction.markDepartureCleaningDue => 'Mark departure cleaning due',
    RoomAction.startCleaning => 'Start cleaning',
    RoomAction.completeCleaning => 'Complete cleaning',
    RoomAction.reportServiceNeeded => 'Report service needed',
    RoomAction.startService => 'Start service',
    RoomAction.completeService => 'Complete service',
  };
}
