import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mobil_application/app.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_config.dart';
import 'package:mobil_application/infrastructure/network/http_auth_repository.dart';
import 'package:mobil_application/infrastructure/network/http_client_factory.dart';
import 'package:mobil_application/infrastructure/network/http_room_repository.dart';
import 'package:mobil_application/infrastructure/storage/secure_session_store.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';

/// The composition root: builds the dependencies and starts the app.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final baseUri = Uri.parse(ApiConfig.baseUrl);
  final session = SessionController(
    store: const SecureSessionStore(FlutterSecureStorage()),
  );
  final client = ApiClient(
    httpClient: createHttpClient(developmentHost: baseUri.host),
    baseUri: baseUri,
    tokenProvider: () => session.token,
    onUnauthorized: session.onUnauthorized,
  );
  unawaited(session.restore());

  runApp(
    NfHotelApp(
      session: session,
      auth: HttpAuthRepository(client),
      rooms: HttpRoomRepository(client),
    ),
  );
}
