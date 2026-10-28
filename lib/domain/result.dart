/// What went wrong with a call to the API, as the screens need to tell it.
enum FailureKind {
  /// The email or the password is wrong.
  invalidCredentials,

  /// The token is missing, expired or not accepted: sign in again.
  unauthorized,

  /// The member may not do that, for example a room they are not assigned to.
  forbidden,

  /// The room or the route does not exist.
  notFound,

  /// The API refused the request, for example a value it does not know.
  rejected,

  /// The API could not be reached, or did not answer in time.
  network,

  /// The API failed, or answered something that is not understood.
  server,
}

/// A failed call.
class ApiFailure {
  /// Creates a failure.
  const ApiFailure(this.kind);

  /// What went wrong.
  final FailureKind kind;

  @override
  String toString() => 'ApiFailure($kind)';
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
