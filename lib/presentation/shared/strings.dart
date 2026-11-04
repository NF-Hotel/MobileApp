import 'package:mobil_application/domain/entities/planning.dart';
import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/planning_repository.dart';
import 'package:mobil_application/domain/result.dart';

/// The texts the screens show, in one place. English only for now; moving them
/// to ARB files with `flutter gen-l10n` is a later step.
abstract final class Strings {
  static const String appTitle = 'NF Hotel';
  static const String signInTitle = 'Sign in';
  static const String userName = 'User name';
  static const String password = 'Password';
  static const String signInButton = 'Sign in';
  static const String showPassword = 'Show password';
  static const String hidePassword = 'Hide password';
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
  static const String serviceNotes = 'Service notes';
  static const String noServiceNotes = 'No service notes on this room.';
  static const String serviceNoteHint = 'What does the room need?';
  static const String reportServiceNeeded = 'Report service needed';
  static const String serviceHistory = 'History';
  static const String noServiceHistory =
      'No finished service on this room yet.';

  // The own account (MIL-059).
  static const String changePassword = 'Change password';
  static const String chooseNewPassword = 'Choose a new password';
  static const String chooseNewPasswordHint =
      'Your password was set by a Manager. Choose your own before you '
      'continue.';
  static const String changePasswordHint =
      'All your other sessions end when the password changes.';
  static const String currentPassword = 'Current password';
  static const String newPassword = 'New password';
  static const String confirmPassword = 'New password again';
  static const String currentPasswordRequired = 'Enter your current password';
  static const String passwordTooShort =
      'The password must be at least 12 characters';
  static const String passwordsDoNotMatch =
      'The two passwords are not the same';
  static const String passwordChanged = 'Your password was changed.';
  static const String saveButton = 'Save';
  static const String yourName = 'Your name';
  static const String welcome = 'Welcome';
  static const String addYourName = 'Add your name before you continue.';
  static const String firstName = 'First name';
  static const String lastName = 'Last name';
  static const String firstNameRequired = 'Enter a first name';
  static const String lastNameRequired = 'Enter a last name';
  static const String continueButton = 'Continue';

  // The administration (MIL-059).
  static const String administration = 'Administration';
  static const String createAccount = 'Create account';
  static const String createAccountHint =
      'Give a member of staff access to the app and the back office.';
  static const String email = 'E-mail (optional)';
  static const String emailInvalid = 'Enter a valid e-mail address';
  static const String temporaryPassword = 'Temporary password';
  static const String temporaryPasswordHint =
      'At least 12 characters. The person must change it at the first sign-in.';
  static const String roleLabel = 'Role';
  static const String accountUserNameRequired = 'Enter a user name';
  static const String users = 'Users';
  static const String noUsers = 'There are no accounts.';
  static const String editName = 'Edit name';
  static const String editEmail = 'Edit e-mail';
  static const String emailClearHint = 'Leave it empty to remove the address.';
  static const String resetPassword = 'Reset password';
  static const String changeRole = 'Change role';
  static const String disableAccount = 'Disable account';
  static const String enableAccount = 'Enable account';
  static const String deleteAccount = 'Delete account';
  static const String actions = 'Actions';
  static const String stateActive = 'Active';
  static const String stateDisabled = 'Disabled';
  static const String stateMustChange = 'Must change password';
  static const String you = 'you';
  static const String delete = 'Delete';
  static const String disable = 'Disable';

  /// The question before an account is deleted.
  static String deleteQuestion(String userName) =>
      'Delete $userName? The account is removed for good and its sessions '
      'end. The audit trail keeps the user name.';

  /// The question before an account is disabled.
  static String disableQuestion(String userName) =>
      '$userName can no longer sign in, and every open session of the account '
      'ends now.';

  /// The title of the reset of the password of an account.
  static String resetPasswordFor(String userName) =>
      'Temporary password for $userName';

  /// The title of the choice of a role for an account.
  static String changeRoleFor(String userName) => 'Role of $userName';

  /// The receipt of a new account.
  static String accountCreated(String userName) =>
      'Created $userName. The person must choose a new password at the first '
      'sign-in.';

  /// The receipt of a change of an account.
  static String accountSaved(String userName) => 'Saved $userName.';

  /// The receipt of a new role.
  static String roleChanged(String userName) =>
      'Saved $userName. The new role ends the open sessions of the account.';

  /// The receipt of a temporary password.
  static String passwordReset(String userName) =>
      'Set a temporary password for $userName. The person must change it at '
      'the next sign-in.';

  /// The receipt of a disabled account.
  static String accountDisabled(String userName) =>
      'Disabled $userName. Their sessions have ended.';

  /// The receipt of an enabled account.
  static String accountEnabled(String userName) =>
      'Enabled $userName. The person must choose a new password at the next '
      'sign-in.';

  /// The receipt of a deleted account.
  static String accountDeleted(String userName) => 'Deleted $userName.';

  static const Map<String, String> _staffTexts = <String, String>{
    'staff.current_password_invalid': 'The current password is wrong.',
    'staff.password_invalid':
        'The password must be between 12 and 256 characters.',
    'staff.password_same_as_user_name':
        'The password must not be the same as the user name.',
    'staff.password_same_as_current':
        'Choose a password that is different from the current one.',
    'staff.password_too_common':
        'That password is too common. Choose another one.',
    'staff.too_many_attempts':
        'Too many wrong passwords. Wait fifteen minutes and try again.',
    'staff.too_many_requests':
        'Too many changes in a short time. Wait a minute and try again.',
    'staff.not_found': 'The account was not found.',
    'staff.user_name_taken': 'That user name is already in use.',
    'staff.user_name_required': 'Enter a user name.',
    'staff.user_name_too_long': 'The user name is too long.',
    'staff.first_name_required': 'Enter a first name.',
    'staff.first_name_too_long': 'The first name is too long.',
    'staff.last_name_required': 'Enter a last name.',
    'staff.last_name_too_long': 'The last name is too long.',
    'staff.email_invalid': 'Enter a valid e-mail address.',
    'staff.email_too_long': 'The e-mail address is too long.',
    'staff.email_taken': 'Another account already has that e-mail address.',
    'staff.role_invalid': 'Select a role.',
    'staff.last_manager':
        'At least one active Manager must remain, so this account cannot be '
        'disabled, deleted or given another role.',
    'staff.cannot_disable_self': 'You cannot disable your own account.',
    'staff.cannot_reset_self': 'Use Change password to set your own password.',
    'staff.cannot_change_own_role': 'You cannot change your own role.',
    'staff.cannot_delete_self': 'You cannot delete your own account.',
    'staff.name_already_set':
        'Your account already has a name. Ask a Manager to change it.',
    'staff.password_change_required':
        'Choose a new password before you continue.',
  };

  // My work and the planning (MIL-060).
  static const String menu = 'Menu';
  static const String myWork = 'My shifts and rooms';
  static const String planning = 'Planning';
  static const String shiftsTab = 'Shifts';
  static const String roomsTab = 'Rooms';
  static const String approvalsTab = 'Approvals';
  static const String myShifts = 'My shifts';
  static const String noShifts = 'You have no shifts in the next four weeks.';
  static const String waitingForYou = 'Waiting for you';
  static const String openShifts = 'Shifts you can take';
  static const String myTrades = 'My trades';
  static const String giveAway = 'Give away';
  static const String swap = 'Swap';
  static const String take = 'Take';
  static const String accept = 'Accept';
  static const String decline = 'Decline';
  static const String withdraw = 'Withdraw';
  static const String approve = 'Approve';
  static const String reject = 'Reject';
  static const String chooseSwap = 'Swap for which shift?';
  static const String noSwapCandidates =
      'No colleague with your role has a shift you can swap for.';
  static const String myRooms = 'My rooms';
  static const String noRooms2 = 'You have no rooms assigned.';
  static const String giveOrTradeRooms = 'Give or trade rooms';
  static const String colleague = 'Colleague';
  static const String roomsToGive = 'Your rooms to give';
  static const String roomsToTake = 'Their rooms you want (optional)';
  static const String send = 'Send';
  static const String needsManager =
      'This leaves somebody with fewer than the minimum of rooms, so a Manager '
      'must approve it after your colleague accepts.';
  static const String leavesTooFew =
      'The colleague accepted. It leaves somebody with fewer than the minimum '
      'of rooms, so it needs your approval.';
  static const String chooseRoomsToGive = 'Choose at least one room to give';
  static const String noColleagues = 'There is no other housekeeper.';
  static const String nothingToApprove = 'Nothing waits for approval.';
  static const String addShift = 'Add shift';
  static const String editShift = 'Edit shift';
  static const String deleteShift = 'Delete shift';
  static const String date = 'Date';
  static const String start = 'Start';
  static const String end = 'End';
  static const String who = 'Who';
  static const String nobodyYet = 'Nobody yet';
  static const String nobody = 'Nobody';
  static const String previousWeek = 'Previous week';
  static const String nextWeek = 'Next week';
  static const String housekeepers = 'Housekeepers';
  static const String belowMinimum = 'below the minimum';
  static const String signInAgainForWork =
      'Sign out and in again to see your shifts and rooms.';

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// A day, for example `Mon 5 Jan`.
  static String day(DateTime value) =>
      '${_weekdays[value.weekday - 1]} ${value.day} ${_months[value.month - 1]}';

  /// The times of a shift, for example `07:00–15:00`.
  static String times(DateTime start, DateTime end) =>
      '${_time(start)}–${_time(end)}';

  /// A shift in one line, for example `Mon 5 Jan 07:00–15:00`.
  static String shiftWhen(DateTime start, DateTime end) =>
      '${day(start)} ${times(start, end)}';

  /// The state of a trade in words.
  static String tradeState(TradeState state) => switch (state) {
    TradeState.open => 'Waiting for the colleague',
    TradeState.awaitingApproval => 'Waiting for a Manager',
    TradeState.done => 'Done',
    TradeState.declined => 'Declined',
    TradeState.rejected => 'Rejected by a Manager',
    TradeState.withdrawn => 'Withdrawn',
    TradeState.cancelled => 'Called off',
  };

  /// The rooms of a trade, for example `101, 102`.
  static String roomNumbers(List<TradedRoom> rooms) =>
      rooms.map((room) => room.roomNumber).join(', ');

  /// The receipt of a step of a trade.
  static String tradeStepDone(TradeStep step) => switch (step) {
    TradeStep.take => 'You took the shift. A Manager will approve it.',
    TradeStep.accept => 'Accepted.',
    TradeStep.decline => 'Declined.',
    TradeStep.withdraw => 'Withdrawn.',
    TradeStep.approve => 'Approved.',
    TradeStep.reject => 'Rejected.',
  };

  static const Map<String, String> _planningTexts = <String, String>{
    'room_trade.not_found': 'That trade was not found.',
    'room_trade.not_yours': 'That trade is not yours to answer.',
    'room_trade.not_open': 'That trade has already been answered.',
    'room_trade.rooms_changed':
        'A room of the trade changed hands meanwhile, so the trade was called '
        'off.',
    'room_trade.no_rooms': 'Choose at least one room to give.',
    'room_trade.duplicate_room': 'A room is chosen twice.',
    'room_trade.same_staff': 'Choose another housekeeper.',
    'room_trade.not_housekeeper':
        'Rooms can only be traded with an active housekeeper.',
    'room_trade.room_not_yours':
        'You can only give rooms that are assigned to you.',
    'room_trade.room_not_theirs':
        'You can only ask for rooms that are assigned to the colleague.',
    'room_assignment.assignee_invalid':
        'Rooms can only be assigned to an active housekeeper.',
    'shift.not_found': 'That shift was not found.',
    'shift.end_before_start': 'The shift must end after it starts.',
    'shift.too_long': 'A shift can be at most 16 hours.',
    'shift.assignee_invalid':
        'The shift can only go to an active member of staff with its role.',
    'shift.overlap': 'That member of staff already has a shift at that time.',
    'shift_trade.not_found': 'That trade was not found.',
    'shift_trade.not_yours': 'That trade is not yours to answer.',
    'shift_trade.not_open': 'That trade has already been answered.',
    'shift_trade.expired':
        'The shift starts within 24 hours, so it can no longer be traded.',
    'shift_trade.already_offered':
        'That shift is already offered in another trade.',
    'shift_trade.wrong_role': 'Only staff with the role of the shift can take it.',
    'shift_trade.own_shift': 'Choose a shift of a colleague.',
    'shift_trade.swap_invalid':
        'That shift cannot be swapped: it has nobody or another role.',
    'shift_trade.shift_changed':
        'A shift of the trade changed hands meanwhile, so the trade was called '
        'off.',
  };

  /// The text of a failure on a shift, a room assignment or a trade.
  static String planningFailure(ApiFailure failure) {
    final texts = <String>{
      for (final code in failure.codes)
        if (_planningTexts[code] case final String text) text,
    };
    if (texts.isNotEmpty) {
      return texts.join('\n');
    }
    if (failure.kind == FailureKind.notFound) {
      return 'Shifts and room assignments are not available on this server '
          'yet.';
    }
    return staffFailure(failure);
  }

  /// The text of a failure on a staff account: the texts of its codes, or the
  /// text of its kind.
  static String staffFailure(ApiFailure failure) {
    final texts = <String>{
      for (final code in failure.codes)
        if (_staffTexts[code] case final String text) text,
    };
    if (texts.isNotEmpty) {
      return texts.join('\n');
    }
    if (failure.kind == FailureKind.notFound) {
      return 'Account management is not available on this server yet.';
    }
    return Strings.failure(failure);
  }

  /// The state of an account in the administration.
  static String accountState(bool isActive, bool mustChangePassword) =>
      !isActive
      ? stateDisabled
      : mustChangePassword
      ? stateMustChange
      : stateActive;

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// The text of a failure on a service note: the codes of the notes first, then
  /// the kind.
  static String serviceNoteFailure(ApiFailure failure) {
    final codes = failure.codes;
    if (codes.contains('room_service_note.undo_window_closed')) {
      return "This note has moved to the room's history. Only a manager can "
          'reopen it now.';
    }
    if (codes.contains('room_service_note.not_found')) {
      return 'The note was not found.';
    }
    if (codes.contains('room_service_note.text_required')) {
      return 'Write what the room needs.';
    }
    if (codes.contains('room_service_note.text_too_long')) {
      return 'The note is too long.';
    }
    if (failure.kind == FailureKind.tooManyAttempts) {
      return 'Too many changes in a short time. Wait a minute and try again.';
    }
    // The API names what it could not find; a 404 without a code comes from
    // before the API, so the server does not offer the route.
    if (failure.kind == FailureKind.notFound && codes.isEmpty) {
      return 'Service notes are not available on this server yet.';
    }
    return Strings.failure(failure);
  }

  /// Who wrote a note and when, in the local time.
  static String serviceNoteWritten(String name, DateTime at) =>
      'Written by $name, ${_dateAndTime(at)}';

  /// Who marked a note as done and when, in the local time.
  static String serviceNoteDone(String name, DateTime at) =>
      'Done by $name, ${_dateAndTime(at)}';

  /// Until when a mark can be undone, in the local time.
  static String serviceNoteUndoableUntil(DateTime until) =>
      'Can be unticked until ${_time(until)}';

  /// The title of the service history of a room.
  static String serviceHistoryTitle(String roomNumber) =>
      '$serviceHistory: $roomTitle $roomNumber';

  static String _dateAndTime(DateTime value) {
    final local = value.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}, '
        '${_time(local)}';
  }

  static String _time(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

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
    RoomAction.reportServiceNeeded => reportServiceNeeded,
    RoomAction.startService => 'Start service',
    RoomAction.completeService => 'Complete service',
  };
}
