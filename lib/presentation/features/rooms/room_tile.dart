import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/presentation/shared/app_theme.dart';
import 'package:mobil_application/presentation/shared/housekeeping_icon.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

/// One room in the overview: the picture of its state, its number and the
/// state in words.
class RoomTile extends StatelessWidget {
  /// Creates the tile.
  const RoomTile({required this.room, required this.onTap, super.key});

  /// The room shown.
  final Room room;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = textTheme.labelMedium;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HousekeepingIcon.forRoom(room, size: 64),
              const SizedBox(height: 12),
              Text(
                '${Strings.roomTitle} ${room.roomNumber}',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                Strings.housekeeping(room.housekeepingStatus),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: label,
              ),
              if (room.status != RoomStatus.available)
                Text(
                  Strings.roomStatus(room.status),
                  style: label?.copyWith(color: AppColors.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
