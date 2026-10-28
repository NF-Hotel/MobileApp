import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';

/// The texts the screens show, in one place. English only for now; moving them
/// to ARB files with `flutter gen-l10n` is a later step.
abstract final class Strings {
  static const String appTitle = 'NF Hotel';
  static const String signInTitle = 'Sign in';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String signInButton = 'Sign in';
  static const String signOut = 'Sign out';
  static const String emailRequired = 'Enter your email';
  static const String passwordRequired = 'Enter your password';
  static const String nameTitle = 'Your name';
  static const String nameIntro = 'Add your name before continuing.';
  static const String firstName = 'First name';
  static const String lastName = 'Last name';
  static const String required = 'Required';
  static const String save = 'Save';
  static const String nameAlreadySet =
      'Your name has already been set. Sign out and in again to continue.';
  static const String roomsTitle = 'Rooms';
  static const String refresh = 'Refresh';
  static const String noRooms = 'There are no rooms for you.';
  static const String retry = 'Try again';
  static const String status = 'Status';
  static const String assigned = 'Assigned';
  static const String nobodyAssigned = 'Nobody';
  static const String notes = 'Notes';
  static const String noNotes = 'No notes yet.';
  static const String newNote = 'Write a note';
  static const String addNote = 'Add note';
  static const String deleteNote = 'Delete note';

  /// The text of a failure, without a code or a stack trace.
  static String failure(ApiFailure failure) => switch (failure.kind) {
    FailureKind.invalidCredentials => 'The email or the password is wrong.',
    FailureKind.unauthorized => 'Your session has ended. Sign in again.',
    FailureKind.forbidden => 'You may not do that.',
    FailureKind.notFound => 'That was not found. It may have been deleted.',
    FailureKind.rejected => 'The hotel system refused the change.',
    FailureKind.network =>
      'The hotel system cannot be reached. Check the connection and try '
          'again.',
    FailureKind.server => 'Something went wrong. Try again later.',
  };

  /// The name of a role.
  static String role(StaffRole role) => switch (role) {
    StaffRole.admin => 'Admin',
    StaffRole.cleaner => 'Cleaner',
    StaffRole.technician => 'Technician',
  };

  /// The cleaning state of a room.
  static String roomStatus(RoomStatus status) => switch (status) {
    RoomStatus.clean => 'Clean',
    RoomStatus.needsCleaning => 'Needs cleaning',
    RoomStatus.dailyCleaning => 'Daily cleaning',
    RoomStatus.needsMaintenance => 'Needs maintenance',
  };

  /// Who wrote a note and when, and who ticked it off.
  static String noteByline(RoomNote note) {
    final written = '${note.createdBy}, ${when(note.createdAt)}';
    final resolvedAt = note.resolvedAt;
    return resolvedAt == null
        ? written
        : '$written\nDone by ${note.resolvedBy}, ${when(resolvedAt)}';
  }

  /// A point in time in local time, as `2026-10-28 14:05`.
  static String when(DateTime time) {
    final t = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}
