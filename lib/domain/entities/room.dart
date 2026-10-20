/// The size of a room.
enum RoomSize {
  /// One bed.
  single,

  /// Two beds.
  double,

  /// A suite.
  suite,
}

/// Whether a room can be let.
enum RoomStatus {
  /// In use as normal.
  available,

  /// Taken out of service.
  outOfService,

  /// Under maintenance.
  maintenance,
}

/// Where a room is in cleaning and service.
enum HousekeepingStatus {
  /// Clean and ready.
  clean,

  /// Waiting for the daily cleaning.
  dailyCleaningDue,

  /// Waiting for the cleaning after a guest left.
  departureCleaningDue,

  /// Being cleaned.
  cleaningInProgress,

  /// Waiting for service.
  serviceRequired,

  /// Being serviced.
  serviceInProgress,
}

/// What the API says may be done with a room now, from its state.
class RoomActions {
  /// Creates the flags.
  const RoomActions({
    this.canMarkDailyCleaningDue = false,
    this.canMarkDepartureCleaningDue = false,
    this.canStartCleaning = false,
    this.canCompleteCleaning = false,
    this.canReportServiceNeeded = false,
    this.canStartService = false,
    this.canCompleteService = false,
  });

  /// Mark for daily cleaning.
  final bool canMarkDailyCleaningDue;

  /// Mark for departure cleaning.
  final bool canMarkDepartureCleaningDue;

  /// Start cleaning.
  final bool canStartCleaning;

  /// Complete cleaning.
  final bool canCompleteCleaning;

  /// Report that service is needed.
  final bool canReportServiceNeeded;

  /// Start service.
  final bool canStartService;

  /// Complete service.
  final bool canCompleteService;

  /// Tells whether [action] is allowed.
  bool allows(RoomAction action) => switch (action) {
    RoomAction.markDailyCleaningDue => canMarkDailyCleaningDue,
    RoomAction.markDepartureCleaningDue => canMarkDepartureCleaningDue,
    RoomAction.startCleaning => canStartCleaning,
    RoomAction.completeCleaning => canCompleteCleaning,
    RoomAction.reportServiceNeeded => canReportServiceNeeded,
    RoomAction.startService => canStartService,
    RoomAction.completeService => canCompleteService,
  };
}

/// The cleaning and service actions of a room that the app offers.
enum RoomAction {
  /// Mark for daily cleaning.
  markDailyCleaningDue,

  /// Mark for departure cleaning.
  markDepartureCleaningDue,

  /// Start cleaning.
  startCleaning,

  /// Complete cleaning.
  completeCleaning,

  /// Report that service is needed.
  reportServiceNeeded,

  /// Start service.
  startService,

  /// Complete service.
  completeService,
}

/// A room of the hotel, as the API reports it.
class Room {
  /// Creates a room.
  const Room({
    required this.roomId,
    required this.roomNumber,
    required this.floor,
    required this.size,
    required this.capacity,
    required this.status,
    required this.housekeepingStatus,
    required this.actions,
  });

  /// The key of the room.
  final int roomId;

  /// The number on the door.
  final String roomNumber;

  /// The floor.
  final int floor;

  /// The size.
  final RoomSize size;

  /// How many guests it sleeps.
  final int capacity;

  /// Whether it can be let.
  final RoomStatus status;

  /// Its cleaning and service state.
  final HousekeepingStatus housekeepingStatus;

  /// What may be done with it now.
  final RoomActions actions;
}
