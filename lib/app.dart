import 'package:flutter/material.dart';

import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/presentation/features/login/login_screen.dart';
import 'package:mobil_application/presentation/features/login/login_view_model.dart';
import 'package:mobil_application/presentation/features/name/name_screen.dart';
import 'package:mobil_application/presentation/features/name/name_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_overview_screen.dart';
import 'package:mobil_application/presentation/features/rooms/room_overview_view_model.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The app: the sign-in until a member of staff is signed in, then their name
/// if the account has none yet, then the rooms.
class NfHotelApp extends StatefulWidget {
  /// Creates the app over its dependencies, which `main` builds.
  const NfHotelApp({
    required this.session,
    required this.auth,
    required this.rooms,
    super.key,
  });

  /// Who is signed in.
  final SessionController session;

  /// Signs a member of staff in.
  final AuthRepository auth;

  /// Reads and changes rooms.
  final RoomRepository rooms;

  @override
  State<NfHotelApp> createState() => _NfHotelAppState();
}

class _NfHotelAppState extends State<NfHotelApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  // set in initState, before the first build
  late final LoginViewModel _login;
  late final NameViewModel _name;
  RoomOverviewViewModel? _overview;

  @override
  void initState() {
    super.initState();
    _login = LoginViewModel(auth: widget.auth, session: widget.session);
    _name = NameViewModel(auth: widget.auth, session: widget.session);
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// Back to the root when the session ends, so a room screen that was open
  /// does not stay on top of the sign-in.
  void _onSessionChanged() {
    if (widget.session.session == null) {
      _overview = null;
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: Strings.appTitle,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) {
          if (widget.session.isRestoring) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final session = widget.session.session;
          if (session == null) {
            return LoginScreen(viewModel: _login);
          }
          if (!session.hasName) {
            return NameScreen(viewModel: _name, session: widget.session);
          }
          return RoomOverviewScreen(
            viewModel: _overview ??= RoomOverviewViewModel(rooms: widget.rooms),
            rooms: widget.rooms,
            session: widget.session,
          );
        },
      ),
    );
  }
}
