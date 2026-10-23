import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// One room in the overview: its number, floor and housekeeping state.
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
    final needsAttention = room.housekeepingStatus != HousekeepingStatus.clean;
    return Card(
      color: needsAttention ? scheme.tertiaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                room.roomNumber,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('Floor ${room.floor}'),
              const SizedBox(height: 8),
              Text(
                Strings.housekeeping(room.housekeepingStatus),
                textAlign: TextAlign.center,
              ),
              if (room.status != RoomStatus.available)
                Text(
                  Strings.roomStatus(room.status),
                  style: TextStyle(color: scheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
