import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/presentation/features/rooms/room_service_history_screen.dart';
import 'package:mobil_application/presentation/features/rooms/room_service_note_tile.dart';
import 'package:mobil_application/presentation/features/rooms/room_service_notes_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_model.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// One room with the cleaning and service actions that its state allows, and its
/// service notes under them.
class RoomViewScreen extends StatefulWidget {
  /// Creates the screen over its [viewModel] and its [notes].
  const RoomViewScreen({
    required this.viewModel,
    required this.notes,
    super.key,
  });

  /// How often the notes are read again while the screen is open, so that a mark
  /// moves to the history on time and the notes of the others show up.
  static const Duration notesRefreshInterval = Duration(seconds: 30);

  /// What the screen shows and does.
  final RoomViewModel viewModel;

  /// The service notes of the room.
  final RoomServiceNotesViewModel notes;

  @override
  State<RoomViewScreen> createState() => _RoomViewScreenState();
}

class _RoomViewScreenState extends State<RoomViewScreen> {
  // Here and not in the section of the notes: a list drops the state of a child
  // that is scrolled away, and the draft must survive that.
  final _draft = TextEditingController();
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
    unawaited(widget.notes.load());
    _refresh = Timer.periodic(
      RoomViewScreen.notesRefreshInterval,
      (_) => unawaited(widget.notes.refresh()),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _draft.dispose();
    super.dispose();
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

  /// A new note also reports that the room needs service, so the room is read
  /// again too.
  Future<void> _report() async {
    final written = await widget.notes.report(_draft.text);
    if (written && mounted) {
      _draft.clear();
      await widget.viewModel.load();
    }
  }

  /// A note taken back from the history also reports that the room needs service,
  /// so the room and the notes are read again on the way back.
  Future<void> _openHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoomServiceHistoryScreen(
          roomNumber: widget.viewModel.room.roomNumber,
          viewModel: widget.notes,
        ),
      ),
    );
    if (mounted) {
      await Future.wait([widget.viewModel.load(), widget.notes.load()]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.viewModel, widget.notes]),
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
              const SizedBox(height: 8),
              const Divider(),
              _ServiceNotes(
                viewModel: widget.notes,
                draft: _draft,
                onReport: () => unawaited(_report()),
                onOpenHistory: () => unawaited(_openHistory()),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The service notes under a room: the current ones, the field for a new one and
/// the way to the history.
class _ServiceNotes extends StatelessWidget {
  const _ServiceNotes({
    required this.viewModel,
    required this.draft,
    required this.onReport,
    required this.onOpenHistory,
  });

  /// The longest text of a note that the API accepts.
  static const int _maxTextLength = 1000;

  final RoomServiceNotesViewModel viewModel;
  final TextEditingController draft;
  final VoidCallback onReport;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final error = viewModel.errorMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                Strings.serviceNotes,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              key: const ValueKey('serviceHistory'),
              onPressed: onOpenHistory,
              icon: const Icon(Icons.history),
              label: const Text(Strings.serviceHistory),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              error,
              key: const ValueKey('notesError'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (viewModel.notes.isEmpty && !viewModel.isBusy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(Strings.noServiceNotes),
          ),
        for (final note in viewModel.notes)
          RoomServiceNoteTile(
            key: ValueKey('note-${note.id}'),
            note: note,
            onToggle: viewModel.isBusy
                ? null
                : () => unawaited(viewModel.toggleDone(note)),
          ),
        if (viewModel.canWrite) ...[
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('noteField'),
            controller: draft,
            // Read-only and not disabled during a call, which would drop the
            // focus and close the keyboard of somebody who is still writing.
            readOnly: viewModel.isBusy,
            minLines: 1,
            maxLines: 4,
            maxLength: _maxTextLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: Strings.serviceNoteHint,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: draft,
            builder: (context, value, _) => FilledButton.tonal(
              key: const ValueKey('reportNote'),
              onPressed: viewModel.isBusy || value.text.trim().isEmpty
                  ? null
                  : onReport,
              child: const Text(Strings.reportServiceNeeded),
            ),
          ),
        ],
      ],
    );
  }
}
