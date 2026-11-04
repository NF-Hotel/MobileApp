// The planning of a Manager (MIL-060): the week of shifts, the rooms of the
// housekeepers, and the trades that wait for approval.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/entities/planning.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/planning_repository.dart';
import 'package:mobil_application/presentation/features/work/planning_screen.dart';
import 'package:mobil_application/presentation/features/work/planning_view_model.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

import '../../support/fakes.dart';

/// Wednesday 21 October 2026, local time.
final DateTime wednesday = DateTime(2026, 10, 21, 10);

Shift plannedShift(int id, DateTime start, {int? assignee, String? name}) =>
    Shift(
      id: id,
      startsAt: start,
      endsAt: start.add(const Duration(hours: 8)),
      role: StaffRole.housekeeping,
      assigneeId: assignee,
      assigneeName: name,
    );

void main() {
  late FakePlanningRepository planning;
  late FakeStaffRepository staff;

  setUp(() {
    planning = FakePlanningRepository()
      ..shifts = [
        plannedShift(
          1,
          DateTime(2026, 10, 20, 7),
          assignee: 7,
          name: 'Hilda Berg',
        ),
        plannedShift(2, DateTime(2026, 10, 28, 7)),
      ]
      ..rooms = const RoomAssignmentOverview(
        rooms: [
          RoomAssignment(
            roomId: 101,
            roomNumber: '101',
            floor: 1,
            staffId: 7,
            staffName: 'Hilda Berg',
          ),
          RoomAssignment(roomId: 102, roomNumber: '102', floor: 1),
        ],
        housekeepers: [
          Housekeeper(id: 7, name: 'Hilda Berg', roomCount: 1),
          Housekeeper(id: 8, name: 'Otto Lund', roomCount: 4),
        ],
        minimumRooms: 3,
      );
    staff = FakeStaffRepository([
      staffAccount(
        id: 7,
        userName: 'hilda',
        role: StaffRole.housekeeping,
        firstName: 'Hilda',
        lastName: 'Berg',
      ),
      staffAccount(
        id: 9,
        userName: 'gone',
        role: StaffRole.housekeeping,
        isActive: false,
      ),
    ]);
  });

  PlanningViewModel viewModel() =>
      PlanningViewModel(planning: planning, staff: staff, now: () => wednesday);

  group('PlanningViewModel', () {
    test('shows the week from Monday, and the next week on demand', () async {
      final model = viewModel();
      await model.load();

      expect(model.weekStart, DateTime(2026, 10, 19));
      expect(model.shiftsOn(DateTime(2026, 10, 20)).single.id, 1);

      await model.nextWeek();

      expect(model.weekStart, DateTime(2026, 10, 26));
      expect(model.shiftsOn(DateTime(2026, 10, 28)).single.id, 2);
    });

    test('an end before the start ends the shift the next day', () async {
      final model = viewModel();
      await model.load();

      await model.saveShift(
        day: DateTime(2026, 10, 22),
        start: const TimeOfDay(hour: 22, minute: 0),
        end: const TimeOfDay(hour: 6, minute: 0),
        role: StaffRole.housekeeping,
        assigneeId: 7,
      );

      expect(
        planning.calls.single,
        startsWith(
          'create:2026-10-22T22:00:00.000>2026-10-23T06:00:00.000:housekeeping:7',
        ),
      );
    });

    test('only active staff with the role can work a shift', () async {
      final model = viewModel();
      await model.load();

      expect(model.staffFor(StaffRole.housekeeping).map((a) => a.id), [7]);
      expect(model.staffFor(StaffRole.receptionist), isEmpty);
      expect(model.isBelowMinimum(model.rooms!.housekeepers.first), isTrue);
      expect(model.isBelowMinimum(model.rooms!.housekeepers.last), isFalse);
    });
  });

  group('PlanningScreen', () {
    Future<void> show(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: PlanningScreen(viewModel: viewModel())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists the week and deletes a shift from its menu', (
      tester,
    ) async {
      await show(tester);

      expect(find.text('Hilda Berg'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plannedShiftMenu-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('deleteShift-1')));
      await tester.pumpAndSettle();

      expect(planning.calls, ['delete:1']);
      expect(find.text('Deleted the shift.'), findsOneWidget);
    });

    testWidgets('plans a shift with the dialog', (tester) async {
      await show(tester);

      await tester.tap(find.byKey(const ValueKey('addShift-21')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveShift')));
      await tester.pumpAndSettle();

      expect(
        planning.calls.single,
        startsWith(
          'create:2026-10-21T07:00:00.000>2026-10-21T15:00:00.000:housekeeping:null',
        ),
      );
      expect(find.text('Planned the shift.'), findsOneWidget);
    });

    testWidgets(
      'assigns a room to a housekeeper and marks a housekeeper below the minimum',
      (tester) async {
        await show(tester);

        await tester.tap(find.text(Strings.roomsTab));
        await tester.pumpAndSettle();
        expect(find.text('1 · ${Strings.belowMinimum}'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('assign-102')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Otto Lund').last);
        await tester.pumpAndSettle();

        expect(planning.calls, ['assign:102:8']);
      },
    );

    testWidgets('approves a trade that waits', (tester) async {
      planning.roomTrades = const [
        RoomTrade(
          id: 3,
          fromStaffId: 7,
          fromName: 'Hilda Berg',
          toStaffId: 8,
          toName: 'Otto Lund',
          give: [TradedRoom(roomId: 101, roomNumber: '101')],
          take: [],
          state: TradeState.awaitingApproval,
        ),
      ];
      await show(tester);

      expect(find.text('${Strings.approvalsTab} (1)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('approvalsTab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('roomApproval-3-approve')));
      await tester.pumpAndSettle();

      expect(planning.calls, ['rooms-${TradeStep.approve.name}:3']);
    });
  });
}
