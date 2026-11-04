import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/repositories/auth_repository.dart';
import 'package:mobil_application/domain/repositories/planning_repository.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/domain/repositories/room_service_note_repository.dart';
import 'package:mobil_application/domain/repositories/staff_repository.dart';
import 'package:mobil_application/presentation/features/account/change_password_screen.dart';
import 'package:mobil_application/presentation/features/account/change_password_view_model.dart';
import 'package:mobil_application/presentation/features/administration/administration_screen.dart';
import 'package:mobil_application/presentation/features/administration/administration_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_overview_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_service_notes_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_tile.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_screen.dart';
import 'package:mobil_application/presentation/features/work/my_work_screen.dart';
import 'package:mobil_application/presentation/features/work/my_work_view_model.dart';
import 'package:mobil_application/presentation/features/work/planning_screen.dart';
import 'package:mobil_application/presentation/features/work/planning_view_model.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/app_theme.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// All rooms of the hotel, with their housekeeping state.
class RoomOverviewScreen extends StatefulWidget {
  /// Creates the screen.
  const RoomOverviewScreen({
    required this.viewModel,
    required this.rooms,
    required this.serviceNotes,
    required this.session,
    required this.auth,
    required this.staff,
    required this.planning,
    super.key,
  });

  /// What the screen shows.
  final RoomOverviewViewModel viewModel;

  /// Used to open a room.
  final RoomRepository rooms;

  /// Used for the service notes of an opened room.
  final RoomServiceNoteRepository serviceNotes;

  /// Who is signed in; the screen can sign them out.
  final SessionController session;

  /// Changes the own password.
  final AuthRepository auth;

  /// Manages the staff accounts, for a Manager.
  final StaffRepository staff;

  /// The shifts, the room assignments and their trades (MIL-060).
  final PlanningRepository planning;

  @override
  State<RoomOverviewScreen> createState() => _RoomOverviewScreenState();
}

class _RoomOverviewScreenState extends State<RoomOverviewScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
  }

  Future<void> _open(Room room) async {
    final session = widget.session.session;
    if (session == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoomViewScreen(
          viewModel: RoomViewModel(rooms: widget.rooms, room: room),
          notes: RoomServiceNotesViewModel(
            notes: widget.serviceNotes,
            roomId: room.roomId,
            role: session.role,
          ),
        ),
      ),
    );
    if (mounted) {
      await widget.viewModel.load();
    }
  }

  Future<void> _openAdministration() async {
    final session = widget.session.session;
    if (session == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdministrationScreen(
          viewModel: AdministrationViewModel(
            staff: widget.staff,
            ownUserName: session.userName,
          ),
        ),
      ),
    );
  }

  Future<void> _openChangePassword() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ChangePasswordScreen(
        viewModel: ChangePasswordViewModel(
          auth: widget.auth,
          session: widget.session,
        ),
      ),
    ),
  );

  Future<void> _openWork() async {
    final session = widget.session.session;
    if (session == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => session.role.canPlan
            ? PlanningScreen(
                viewModel: PlanningViewModel(
                  planning: widget.planning,
                  staff: widget.staff,
                ),
              )
            : MyWorkScreen(
                viewModel: MyWorkViewModel(
                  planning: widget.planning,
                  session: session,
                ),
              ),
      ),
    );
  }

  /// Closes the menu, then opens [page].
  void _fromMenu(Future<void> Function() page) {
    Navigator.of(context).pop();
    unawaited(page());
  }

  Widget _menu(BuildContext context) {
    final session = widget.session.session;
    final textTheme = Theme.of(context).textTheme;
    final canPlan = session?.role.canPlan ?? false;
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.navy),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  Strings.appTitle,
                  style: textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                if (session != null)
                  Text(
                    '${session.displayName} · ${Strings.role(session.role)}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.amber,
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.meeting_room),
            title: const Text(Strings.roomsTitle),
            selected: true,
            onTap: () => Navigator.of(context).pop(),
          ),
          ListTile(
            key: const ValueKey('menuWork'),
            leading: Icon(canPlan ? Icons.calendar_month : Icons.event_note),
            title: Text(canPlan ? Strings.planning : Strings.myWork),
            onTap: () => _fromMenu(_openWork),
          ),
          if (session != null && session.role.canManageStaff)
            ListTile(
              key: const ValueKey('administration'),
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text(Strings.administration),
              onTap: () => _fromMenu(_openAdministration),
            ),
          const Divider(),
          ListTile(
            key: const ValueKey('changePassword'),
            leading: const Icon(Icons.lock_reset),
            title: const Text(Strings.changePassword),
            onTap: () => _fromMenu(_openChangePassword),
          ),
          ListTile(
            key: const ValueKey('menuSignOut'),
            leading: const Icon(Icons.logout),
            title: const Text(Strings.signOut),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(widget.session.signOut());
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session.session;
    return Scaffold(
      drawer: _menu(context),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            key: const ValueKey('menu'),
            tooltip: Strings.menu,
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(Strings.roomsTitle),
            if (session != null)
              Text(
                '${session.displayName} (${Strings.role(session.role)})',
                key: const ValueKey('signedInAs'),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('refresh'),
            tooltip: Strings.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(widget.viewModel.load()),
          ),
          IconButton(
            key: const ValueKey('signOut'),
            tooltip: Strings.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => unawaited(widget.session.signOut()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) => _RoomOverviewBody(
          viewModel: widget.viewModel,
          onOpen: (room) => unawaited(_open(room)),
        ),
      ),
    );
  }
}

/// What the overview shows for the state of its view model: a spinner, the
/// message of a failure with a retry, or the grid of rooms.
class _RoomOverviewBody extends StatelessWidget {
  const _RoomOverviewBody({required this.viewModel, required this.onOpen});

  final RoomOverviewViewModel viewModel;
  final void Function(Room room) onOpen;

  @override
  Widget build(BuildContext context) {
    switch (viewModel.state) {
      case RoomOverviewState.loading:
        return const Center(child: CircularProgressIndicator());
      case RoomOverviewState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  viewModel.errorMessage ?? '',
                  key: const ValueKey('roomsError'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => unawaited(viewModel.load()),
                  child: const Text(Strings.retry),
                ),
              ],
            ),
          ),
        );
      case RoomOverviewState.ready:
        if (viewModel.rooms.isEmpty) {
          return const Center(child: Text(Strings.noRooms));
        }
        return RefreshIndicator(
          onRefresh: viewModel.load,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            // Two columns on a phone, more on a wider screen.
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.8,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: viewModel.rooms.length,
            itemBuilder: (context, index) {
              final room = viewModel.rooms[index];
              return RoomTile(
                key: ValueKey('room-${room.roomId}'),
                room: room,
                onTap: () => onOpen(room),
              );
            },
          ),
        );
    }
  }
}
