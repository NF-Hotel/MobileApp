/// Where the app finds the NF Hotel API (ADR-0015).
///
/// The address can be set when the app is built:
/// `flutter run --dart-define=API_BASE_URL=https://localhost:8443/mobile-api`.
/// Without it, a release build uses the production server and any other build
/// uses the development server on the host of an Android emulator.
/// No secret belongs here: the app holds no token of the web application.
abstract final class ApiConfig {
  static const String _production = 'https://nfhotel.devmatiker.com/mobile-api';
  static const String _development = 'https://10.0.2.2:8443/mobile-api';

  static const bool _isRelease = bool.fromEnvironment('dart.vm.product');

  /// The base address, without a trailing slash.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _isRelease ? _production : _development,
  );
}
