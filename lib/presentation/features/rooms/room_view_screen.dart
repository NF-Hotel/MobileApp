import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/presentation/features/rooms/room_tile.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_model.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// One room: its cleaning state, who is assigned, and its notes.
class RoomViewScreen extends StatefulWidget {
  /// Creates the screen over its [viewModel].
  const RoomViewScreen({required this.viewModel, super.key});

  /// What the screen shows and does.
  final RoomViewModel viewModel;

  @override
  State<RoomViewScreen> createState() => _RoomViewScreenState();
}

class _RoomViewScreenState extends State<RoomViewScreen> {
  final _newNote = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
  }

  @override
  void dispose() {
    _newNote.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    if (await widget.viewModel.addNote(_newNote.text)) {
      _newNote.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final room = viewModel.room;
        final error = viewModel.errorMessage;
        final busy = viewModel.isBusy;
        return Scaffold(
          appBar: AppBar(title: Text(room.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              Text(
                Strings.status,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in RoomStatus.values)
                    ChoiceChip(
                      key: ValueKey('status-${status.name}'),
                      avatar: Icon(roomStatusIcon(status)),
                      label: Text(Strings.roomStatus(status)),
                      selected: room.status == status,
                      onSelected: busy || room.status == status
                          ? null
                          : (_) => unawaited(viewModel.setStatus(status)),
                    ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  room.cleaners.isEmpty
                      ? Strings.nobodyAssigned
                      : room.cleaners.join(', '),
                ),
                subtitle: const Text(Strings.assigned),
              ),
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
              const Divider(),
              Text(
                Strings.notes,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextField(
                key: const ValueKey('newNote'),
                controller: _newNote,
                enabled: !busy,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: Strings.newNote,
                  suffixIcon: IconButton(
                    key: const ValueKey('addNote'),
                    tooltip: Strings.addNote,
                    icon: const Icon(Icons.send),
                    onPressed: busy ? null : () => unawaited(_addNote()),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (viewModel.notes.isEmpty)
                const Text(Strings.noNotes)
              else
                for (final note in viewModel.notes)
                  ListTile(
                    key: ValueKey('note-${note.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      key: ValueKey('resolve-${note.id}'),
                      value: note.isResolved,
                      onChanged: busy || !viewModel.canToggle(note)
                          ? null
                          : (value) => unawaited(
                              viewModel.setResolved(note, value ?? false),
                            ),
                    ),
                    title: Text(
                      note.body,
                      style: note.isResolved
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
                    ),
                    subtitle: Text(Strings.noteByline(note)),
                    trailing: viewModel.canDelete(note)
                        ? IconButton(
                            key: ValueKey('delete-${note.id}'),
                            tooltip: Strings.deleteNote,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: busy
                                ? null
                                : () => unawaited(viewModel.deleteNote(note)),
                          )
                        : null,
                  ),
            ],
          ),
        );
      },
    );
  }
}
