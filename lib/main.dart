import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobil_application/app.dart';
import 'package:mobil_application/infrastructure/network/api_client.dart';
import 'package:mobil_application/infrastructure/network/api_config.dart';
import 'package:mobil_application/infrastructure/network/http_auth_repository.dart';
import 'package:mobil_application/infrastructure/network/http_client_factory.dart';
import 'package:mobil_application/infrastructure/network/http_planning_repository.dart';
import 'package:mobil_application/infrastructure/network/http_room_repository.dart';
import 'package:mobil_application/infrastructure/network/http_room_service_note_repository.dart';
import 'package:mobil_application/infrastructure/network/http_staff_repository.dart';
import 'package:mobil_application/infrastructure/storage/secure_session_store.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';

/// The composition root: builds the dependencies and starts the app.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _useBundledFonts();

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
      serviceNotes: HttpRoomServiceNoteRepository(client),
      staff: HttpStaffRepository(client),
      planning: HttpPlanningRepository(client),
    ),
  );
}

/// The fonts come from `assets/google_fonts`, never from the internet, so that
/// the app talks to the NF Hotel API only. Their licence shows in the licences
/// of the app.
void _useBundledFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Inter', 'PlayfairDisplay']) {
      final license = await rootBundle.loadString(
        'assets/google_fonts/OFL-$font.txt',
      );
      yield LicenseEntryWithLineBreaks(['google_fonts'], license);
    }
  });
}
