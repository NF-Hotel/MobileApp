import 'package:flutter/material.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/presentation/shared/app_theme.dart';

/// The picture of the state of a room: a barrier for a room out of service, a
/// hammer for maintenance or service, a bed for the daily cleaning, a mop for a
/// cleaning, and a green tick for a clean room in use.
class HousekeepingIcon extends StatelessWidget {
  /// Creates the icon of [status], for a room whose own status is [roomStatus].
  const HousekeepingIcon({
    required this.status,
    this.roomStatus = RoomStatus.available,
    this.size = 32,
    super.key,
  });

  /// Creates the icon of [room]. A room that cannot be let shows that, whatever
  /// its cleaning state: a clean room in maintenance is not ready for a guest.
  HousekeepingIcon.forRoom(Room room, {double size = 32, Key? key})
    : this(
        status: room.housekeepingStatus,
        roomStatus: room.status,
        size: size,
        key: key,
      );

  /// Creates the icon of the state that [action] is about.
  HousekeepingIcon.forAction(RoomAction action, {double size = 32, Key? key})
    : this(status: _statusOf(action), size: size, key: key);

  /// The cleaning and service state, shown while the room is in use.
  final HousekeepingStatus status;

  /// Whether the room can be let; it comes before [status].
  final RoomStatus roomStatus;

  /// The width and the height.
  final double size;

  static const String _bed = 'lib/Assets/ImageBed.png';
  static const String _mop = 'lib/Assets/ImageMop.png';
  static const String _hammer = 'lib/Assets/ImageHammer.png';
  static const String _outOfService = 'lib/Assets/ImageOutOfService.png';

  static HousekeepingStatus _statusOf(RoomAction action) => switch (action) {
    RoomAction.markDailyCleaningDue => HousekeepingStatus.dailyCleaningDue,
    RoomAction.markDepartureCleaningDue =>
      HousekeepingStatus.departureCleaningDue,
    RoomAction.startCleaning => HousekeepingStatus.cleaningInProgress,
    RoomAction.reportServiceNeeded => HousekeepingStatus.serviceRequired,
    RoomAction.startService => HousekeepingStatus.serviceInProgress,
    RoomAction.completeCleaning ||
    RoomAction.completeService => HousekeepingStatus.clean,
  };

  /// The picture of a room, or null for the green tick.
  @visibleForTesting
  static String? assetOf(HousekeepingStatus status, RoomStatus roomStatus) =>
      switch (roomStatus) {
        RoomStatus.outOfService => _outOfService,
        RoomStatus.maintenance => _hammer,
        RoomStatus.available => _assetOfHousekeeping(status),
      };

  static String? _assetOfHousekeeping(HousekeepingStatus status) =>
      switch (status) {
        HousekeepingStatus.clean => null,
        HousekeepingStatus.dailyCleaningDue => _bed,
        HousekeepingStatus.departureCleaningDue ||
        HousekeepingStatus.cleaningInProgress => _mop,
        HousekeepingStatus.serviceRequired ||
        HousekeepingStatus.serviceInProgress => _hammer,
      };

  @override
  Widget build(BuildContext context) {
    final asset = assetOf(status, roomStatus);
    if (asset == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.clean,
          borderRadius: BorderRadius.circular(size / 4),
        ),
        child: Icon(Icons.check_rounded, color: Colors.white, size: size / 2),
      );
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(Icons.broken_image, size: size),
    );
  }
}
