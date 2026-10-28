import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/repositories/room_repository.dart';
import 'package:mobil_application/presentation/features/rooms/room_overview_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_tile.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_screen.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The rooms the member may see, with their cleaning state.
class RoomOverviewScreen extends StatefulWidget {
  /// Creates the screen.
  const RoomOverviewScreen({
    required this.viewModel,
    required this.rooms,
    required this.session,
    super.key,
  });

  /// What the screen shows.
  final RoomOverviewViewModel viewModel;

  /// Used to open a room.
  final RoomRepository rooms;

  /// Who is signed in; the screen can sign them out.
  final SessionController session;

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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoomViewScreen(
          viewModel: RoomViewModel(
            rooms: widget.rooms,
            room: room,
            viewer: widget.session.session!,
          ),
        ),
      ),
    );
    if (mounted) {
      await widget.viewModel.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session.session;
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.roomsTitle),
        actions: [
          if (session != null)
            Center(
              child: Text(
                '${session.displayName} (${Strings.role(session.role)})',
                key: const ValueKey('signedInAs'),
              ),
            ),
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
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 1,
            ),
            itemCount: viewModel.rooms.length,
            itemBuilder: (context, index) {
              final room = viewModel.rooms[index];
              return RoomTile(
                key: ValueKey('room-${room.number}'),
                room: room,
                onTap: () => onOpen(room),
              );
            },
          ),
        );
    }
  }
}
