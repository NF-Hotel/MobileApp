import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// The icon of a cleaning state.
IconData roomStatusIcon(RoomStatus status) => switch (status) {
  RoomStatus.clean => Icons.check_circle_outline,
  RoomStatus.needsCleaning => Icons.cleaning_services,
  RoomStatus.dailyCleaning => Icons.bed,
  RoomStatus.needsMaintenance => Icons.build,
};

/// One room in the overview: its name, cleaning state and cleaners.
class RoomTile extends StatelessWidget {
  /// Creates the tile.
  const RoomTile({required this.room, required this.onTap, super.key});

  /// The room shown.
  final Room room;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: room.status == RoomStatus.clean ? null : scheme.tertiaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                room.name,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Icon(roomStatusIcon(room.status)),
              Text(
                Strings.roomStatus(room.status),
                textAlign: TextAlign.center,
              ),
              if (room.cleaners.isNotEmpty)
                Text(
                  room.cleaners.join(', '),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
