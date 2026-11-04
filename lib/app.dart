import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/domain/repositories/room_service_note_repository.dart';
import 'package:mobil_application/domain/repositories/staff_repository.dart';
import 'package:mobil_application/presentation/features/account/change_password_screen.dart';
import 'package:mobil_application/presentation/features/account/change_password_view_model.dart';
import 'package:mobil_application/presentation/features/account/name_setup_screen.dart';
import 'package:mobil_application/presentation/features/account/name_setup_view_model.dart';
import 'package:mobil_application/presentation/features/login/login_screen.dart';
import 'package:mobil_application/presentation/features/login/login_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_overview_screen.dart';
import 'package:mobil_application/presentation/features/rooms/room_overview_view_model.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/app_theme.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The app: the sign-in until a member of staff is signed in, then the change of
/// a temporary password and the name of an account that has none, then the
/// rooms.
class NfHotelApp extends StatefulWidget {
  /// Creates the app over its dependencies, which `main` builds.
  const NfHotelApp({
    required this.session,
    required this.auth,
    required this.rooms,
    required this.serviceNotes,
    required this.staff,
    super.key,
  });

  /// Who is signed in.
  final SessionController session;

  /// Signs a member of staff in.
  final AuthRepository auth;

  /// Reads and changes rooms.
  final RoomRepository rooms;

  /// Reads and changes the service notes of the rooms.
  final RoomServiceNoteRepository serviceNotes;

  /// Manages the staff accounts, for a Manager.
  final StaffRepository staff;

  @override
  State<NfHotelApp> createState() => _NfHotelAppState();
}

class _NfHotelAppState extends State<NfHotelApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final LoginViewModel _login; // set in initState, before the first build
  late final ChangePasswordViewModel _changePassword;
  late final NameSetupViewModel _nameSetup;
  RoomOverviewViewModel? _overview;

  @override
  void initState() {
    super.initState();
    _login = LoginViewModel(auth: widget.auth, session: widget.session);
    _changePassword = ChangePasswordViewModel(
      auth: widget.auth,
      session: widget.session,
    );
    _nameSetup = NameSetupViewModel(auth: widget.auth, session: widget.session);
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
      theme: buildAppTheme(),
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
          // The API refuses everything else until a temporary password is
          // changed (ADR-0017).
          if (session.mustChangePassword) {
            return ChangePasswordScreen(
              viewModel: _changePassword,
              forced: true,
              onSignOut: () => unawaited(widget.session.signOut()),
            );
          }
          if (widget.session.needsName) {
            return NameSetupScreen(
              viewModel: _nameSetup,
              onSignOut: () => unawaited(widget.session.signOut()),
            );
          }
          return RoomOverviewScreen(
            viewModel: _overview ??= RoomOverviewViewModel(rooms: widget.rooms),
            rooms: widget.rooms,
            serviceNotes: widget.serviceNotes,
            session: widget.session,
            auth: widget.auth,
            staff: widget.staff,
          );
        },
      ),
    );
  }
}
