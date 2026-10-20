/// What went wrong with a call to the API, as the screens need to tell it.
enum FailureKind {
  /// The user name or the password is wrong.
  invalidCredentials,

  /// Too many failed sign-ins; try again later.
  tooManyAttempts,

  /// The staff token is missing, expired or not accepted: sign in again.
  unauthorized,

  /// The role of the member of staff does not hold the permission.
  forbidden,

  /// The room or the route does not exist.
  notFound,

  /// The API refused the request, for example an action that the room state
  /// does not allow.
  rejected,

  /// The API could not be reached, or did not answer in time.
  network,

  /// The API failed, or answered something that is not understood.
  server,
}

/// A failed call: the kind, and the error codes that the API sent.
class ApiFailure {
  /// Creates a failure.
  const ApiFailure(this.kind, [this.codes = const <String>[]]);

  /// What went wrong.
  final FailureKind kind;

  /// The error codes of the API envelope, for example `room.not_found`.
  final List<String> codes;

  @override
  String toString() => 'ApiFailure($kind, $codes)';
}

/// The outcome of a call: a value, or a failure the screen renders as state.
sealed class Result<T> {
  const Result();
}

/// The call succeeded.
final class Success<T> extends Result<T> {
  /// Creates a success.
  const Success(this.value);

  /// The value the API returned.
  final T value;
}

/// The call failed.
final class Failed<T> extends Result<T> {
  /// Creates a failure result.
  const Failed(this.failure);

  /// Why it failed.
  final ApiFailure failure;
}
