import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room_service_note.dart';
import 'package:mobil_application/presentation/shared/app_theme.dart';
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
    final small = Theme.of(context).textTheme.bodySmall;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        key: ValueKey('noteDone-${note.id}'),
        value: note.isDone,
        onChanged: toggle == null ? null : (_) => toggle(),
      ),
      title: Text(
        note.text,
        style: note.isDone
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Strings.serviceNoteWritten(note.writtenBy, note.writtenAt),
            style: small,
          ),
          if (doneBy != null && doneAt != null)
            Row(
              children: [
                const Icon(Icons.fingerprint, size: 16, color: AppColors.navy),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    Strings.serviceNoteDone(doneBy, doneAt),
                    style: small,
                  ),
                ),
              ],
            ),
          if (showUndoDeadline && undoableUntil != null)
            Text(Strings.serviceNoteUndoableUntil(undoableUntil), style: small),
        ],
      ),
    );
  }
}
