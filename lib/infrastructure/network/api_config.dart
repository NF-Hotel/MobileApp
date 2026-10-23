/// Where the app finds the NF Hotel API (ADR-0015).
///
/// The address is set when the app is built:
/// `flutter run --dart-define=API_BASE_URL=https://localhost:8443/mobile-api`.
/// The default is the development server on the host of an Android emulator.
/// No secret belongs here: the app holds no token of the web application.
abstract final class ApiConfig {
  /// The base address, without a trailing slash.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://10.0.2.2:8443/mobile-api',
  );
}
