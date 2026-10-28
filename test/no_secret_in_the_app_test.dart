// The app keeps the access token only in secure storage and holds no secret of
// its own. The token itself is sent as a bearer token, which the LoginApi needs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _sources(String folder) => Directory(folder)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList();

void main() {
  final lib = _sources('lib');

  test('the access token is not kept in plain preferences', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final offenders = lib
        .where((file) => file.readAsStringSync().contains('shared_preferences'))
        .map((file) => file.path)
        .toList();

    expect(pubspec, isNot(contains('shared_preferences')));
    expect(offenders, isEmpty);
  });

  test('no token or key is written as a literal in the sources', () {
    final suspicious = RegExp(
      r'''(api[_-]?token|signing[_-]?key|passport[_-]?key)\s*[:=]\s*['"][^'"]{8,}''',
      caseSensitive: false,
    );
    final offenders = [...lib, ..._sources('test')]
        .where((file) => suspicious.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();

    expect(offenders, isEmpty);
  });

  test('the development certificate is accepted in a debug build only', () {
    final factory = File(
      'lib/infrastructure/network/http_client_factory_io.dart',
    ).readAsStringSync();

    expect(factory, contains('kDebugMode'));
    expect(factory, contains('badCertificateCallback'));
  });
}
