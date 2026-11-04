// The picture of a room: its own status comes before its cleaning state, so a
// clean room that cannot be let never shows the green tick.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/presentation/features/rooms/room_tile.dart';
import 'package:mobil_application/presentation/shared/housekeeping_icon.dart';

import '../../support/fakes.dart';

const String _outOfService = 'lib/Assets/ImageOutOfService.png';
const String _hammer = 'lib/Assets/ImageHammer.png';

void main() {
  group('HousekeepingIcon.assetOf', () {
    test('a room out of service shows the barrier in every cleaning state', () {
      for (final status in HousekeepingStatus.values) {
        expect(
          HousekeepingIcon.assetOf(status, RoomStatus.outOfService),
          _outOfService,
          reason: status.name,
        );
      }
    });

    test('a room in maintenance shows the hammer in every cleaning state', () {
      for (final status in HousekeepingStatus.values) {
        expect(
          HousekeepingIcon.assetOf(status, RoomStatus.maintenance),
          _hammer,
          reason: status.name,
        );
      }
    });

    test('a room in use shows its cleaning state', () {
      expect(
        HousekeepingIcon.assetOf(
          HousekeepingStatus.clean,
          RoomStatus.available,
        ),
        isNull,
      );
      expect(
        HousekeepingIcon.assetOf(
          HousekeepingStatus.dailyCleaningDue,
          RoomStatus.available,
        ),
        'lib/Assets/ImageBed.png',
      );
      expect(
        HousekeepingIcon.assetOf(
          HousekeepingStatus.cleaningInProgress,
          RoomStatus.available,
        ),
        'lib/Assets/ImageMop.png',
      );
    });
  });

  group('RoomTile', () {
    Future<void> show(WidgetTester tester, Room shown) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 220,
            child: RoomTile(room: shown, onTap: () {}),
          ),
        ),
      ),
    );

    String? shownAsset(WidgetTester tester) {
      final images = tester.widgetList<Image>(find.byType(Image));
      return images.isEmpty
          ? null
          : (images.single.image as AssetImage).assetName;
    }

    testWidgets('a clean room in maintenance shows the hammer, not the tick', (
      tester,
    ) async {
      await show(tester, room(status: RoomStatus.maintenance));

      expect(shownAsset(tester), _hammer);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.text('Maintenance'), findsOneWidget);
    });

    testWidgets('a room out of service shows the barrier', (tester) async {
      await show(
        tester,
        room(
          status: RoomStatus.outOfService,
          housekeeping: HousekeepingStatus.dailyCleaningDue,
        ),
      );

      expect(shownAsset(tester), _outOfService);
      expect(find.text('Out of service'), findsOneWidget);
    });

    testWidgets('a clean room in use shows the green tick', (tester) async {
      await show(tester, room());

      expect(shownAsset(tester), isNull);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
