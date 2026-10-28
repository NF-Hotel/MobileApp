/// Where the app finds the LoginApi (`api/` in this repository).
///
/// The address is set when the app is built:
/// `flutter run --dart-define=API_BASE_URL=http://localhost:5142`.
/// The default is the `http` profile of the API (port 5142) on the host of an
/// Android emulator. No secret belongs here.
abstract final class ApiConfig {
  /// The base address, without a trailing slash.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5142',
  );
}
