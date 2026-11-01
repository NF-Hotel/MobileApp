import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_model.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// One room with the cleaning and service actions that its state allows.
class RoomViewScreen extends StatefulWidget {
  /// Creates the screen over its [viewModel].
  const RoomViewScreen({required this.viewModel, super.key});

  /// What the screen shows and does.
  final RoomViewModel viewModel;

  @override
  State<RoomViewScreen> createState() => _RoomViewScreenState();
}

class _RoomViewScreenState extends State<RoomViewScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
  }

  Future<void> _perform(RoomAction action) async {
    var requiresCleaning = false;
    if (action == RoomAction.completeService) {
      final answer = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(Strings.cleaningFollows),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(Strings.cancel),
            ),
            TextButton(
              key: const ValueKey('cleaningFollowsNo'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(Strings.no),
            ),
            TextButton(
              key: const ValueKey('cleaningFollowsYes'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(Strings.yes),
            ),
          ],
        ),
      );
      if (answer == null) {
        return;
      }
      requiresCleaning = answer;
    }
    await widget.viewModel.perform(action, requiresCleaning: requiresCleaning);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final room = viewModel.room;
        final error = viewModel.errorMessage;
        final actions = viewModel.actions;
        return Scaffold(
          appBar: AppBar(
            title: Text('${Strings.roomTitle} ${room.roomNumber}'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (viewModel.isBusy) const LinearProgressIndicator(),
              ListTile(
                title: Text(Strings.housekeeping(room.housekeepingStatus)),
                subtitle: const Text('Cleaning and service'),
              ),
              ListTile(
                title: Text(Strings.roomStatus(room.status)),
                subtitle: const Text('Status'),
              ),
              ListTile(
                title: Text(
                  '${Strings.size(room.size)}, sleeps ${room.capacity}, '
                  'floor ${room.floor}',
                ),
              ),
              const Divider(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    error,
                    key: const ValueKey('roomError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (actions.isEmpty)
                const Text(Strings.nothingToDo)
              else
                for (final action in actions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: FilledButton(
                      key: ValueKey('action-${action.name}'),
                      onPressed: viewModel.isBusy
                          ? null
                          : () => unawaited(_perform(action)),
                      child: Text(Strings.action(action)),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
