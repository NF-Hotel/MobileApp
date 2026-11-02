import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room_service_note.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// One service note: the box for done, the text, who wrote it and who marked it.
class RoomServiceNoteTile extends StatelessWidget {
  /// Creates the tile.
  const RoomServiceNoteTile({
    required this.note,
    required this.onToggle,
    this.showUndoDeadline = true,
    super.key,
  });

  /// The note shown.
  final RoomServiceNote note;

  /// Called when the box is tapped; null locks the box.
  final VoidCallback? onToggle;

  /// Whether to say until when the mark can be undone.
  final bool showUndoDeadline;

  @override
  Widget build(BuildContext context) {
    final doneBy = note.doneBy;
    final doneAt = note.doneAt;
    final undoableUntil = note.undoableUntil;
    final toggle = onToggle;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        key: ValueKey('noteDone-${note.id}'),
        value: note.isDone,
        onChanged: toggle == null ? null : (_) => toggle(),
      ),
      title: Text(note.text),
      subtitle: Text(
        [
          Strings.serviceNoteWritten(note.writtenBy, note.writtenAt),
          if (doneBy != null && doneAt != null)
            Strings.serviceNoteDone(doneBy, doneAt),
          if (showUndoDeadline && undoableUntil != null)
            Strings.serviceNoteUndoableUntil(undoableUntil),
        ].join('\n'),
      ),
    );
  }
}
