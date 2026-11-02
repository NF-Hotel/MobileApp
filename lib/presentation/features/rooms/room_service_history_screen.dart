import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/presentation/features/rooms/room_service_note_tile.dart';
import 'package:mobil_application/presentation/features/rooms/room_service_notes_view_model.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The finished service of one room. Everybody can read it; the boxes are locked
/// for everybody but a Manager, who unticks one to open the note again.
class RoomServiceHistoryScreen extends StatefulWidget {
  /// Creates the screen for the room with the number [roomNumber].
  const RoomServiceHistoryScreen({
    required this.roomNumber,
    required this.viewModel,
    super.key,
  });

  /// The number on the door.
  final String roomNumber;

  /// What the screen shows and does.
  final RoomServiceNotesViewModel viewModel;

  @override
  State<RoomServiceHistoryScreen> createState() =>
      _RoomServiceHistoryScreenState();
}

class _RoomServiceHistoryScreenState extends State<RoomServiceHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // After the frame: the room screen below this one listens to the same view
    // model, and must not be told of a change while this one is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.viewModel.loadHistory());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.serviceHistoryTitle(widget.roomNumber)),
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final viewModel = widget.viewModel;
          final error = viewModel.errorMessage;
          final isWorking = viewModel.isBusy || viewModel.isReadingHistory;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isWorking) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    error,
                    key: const ValueKey('historyError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (viewModel.hasReadHistory && viewModel.history.isEmpty)
                const Text(Strings.noServiceHistory),
              for (final note in viewModel.history)
                RoomServiceNoteTile(
                  key: ValueKey('historyNote-${note.id}'),
                  note: note,
                  showUndoDeadline: false,
                  onToggle: viewModel.canReopen && !isWorking
                      ? () => unawaited(viewModel.reopen(note))
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }
}
