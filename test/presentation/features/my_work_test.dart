// The own shifts and rooms of a housekeeper (MIL-060): giving away, swapping,
// taking and answering trades, and giving or trading rooms.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/entities/planning.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/repositories/planning_repository.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/features/work/my_work_screen.dart';
import 'package:mobil_application/presentation/features/work/my_work_view_model.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

import '../../support/fakes.dart';

const int me = 7;
const int otto = 8;
const int nora = 9;

/// A shift of [assignee] that starts [days] after [testNow].
Shift shift(int id, int assignee, int days, {String? name}) => Shift(
  id: id,
  startsAt: testNow.add(Duration(days: days)),
  endsAt: testNow.add(Duration(days: days, hours: 8)),
  role: StaffRole.housekeeping,
  assigneeId: assignee,
  assigneeName: name,
);

RoomAssignment roomOf(int id, int? staffId) =>
    RoomAssignment(roomId: id, roomNumber: '$id', floor: 1, staffId: staffId);

void main() {
  late FakePlanningRepository planning;

  setUp(() {
    planning = FakePlanningRepository()
      ..shifts = [
        shift(1, me, 2),
        shift(2, otto, 3, name: 'Otto Lund'),
        shift(3, me, 0),
      ]
      ..rooms = RoomAssignmentOverview(
        rooms: [
          roomOf(101, me),
          roomOf(102, me),
          roomOf(103, me),
          roomOf(201, otto),
          roomOf(202, otto),
        ],
        housekeepers: const [
          Housekeeper(id: me, name: 'Hilda Berg', roomCount: 3),
          Housekeeper(id: otto, name: 'Otto Lund', roomCount: 2),
        ],
        minimumRooms: 3,
      );
  });

  MyWorkViewModel viewModel({StaffRole role = StaffRole.housekeeping}) =>
      MyWorkViewModel(
        planning: planning,
        session: validSession(role: role, staffId: me),
        now: () => testNow,
      );

  group('MyWorkViewModel', () {
    test(
      'lists the own shifts that have not ended, and what can be offered',
      () async {
        final model = viewModel();
        await model.load();

        expect(model.myShifts.map((s) => s.id), [1, 3]);
        expect(model.canOffer(model.myShifts.first), isTrue);
        // Shift 3 starts now: within the 24 hours.
        expect(model.canOffer(model.myShifts.last), isFalse);
        expect(model.swapCandidatesFor(model.myShifts.first).map((s) => s.id), [
          2,
        ]);
      },
    );

    test(
      'sorts the trades into those waiting for me, open, and my own',
      () async {
        final mine = shift(1, me, 2);
        final his = shift(2, otto, 3, name: 'Otto Lund');
        planning.shiftTrades = [
          ShiftTrade(
            id: 1,
            shift: his,
            swapShift: mine,
            offeredById: otto,
            offeredByName: 'Otto Lund',
            takenById: me,
            state: TradeState.open,
            isClosed: false,
          ),
          ShiftTrade(
            id: 2,
            shift: shift(4, nora, 5),
            offeredById: nora,
            offeredByName: 'Nora',
            state: TradeState.open,
            isClosed: false,
          ),
          ShiftTrade(
            id: 3,
            shift: mine,
            offeredById: me,
            offeredByName: 'Hilda Berg',
            state: TradeState.awaitingApproval,
            takenById: nora,
            isClosed: false,
          ),
        ];
        final model = viewModel();
        await model.load();

        expect(model.swapsForMe.map((t) => t.id), [1]);
        expect(model.openShifts.map((t) => t.id), [2]);
        expect(model.myShiftTrades.map((t) => t.id), [3]);
        expect(model.canWithdrawShift(model.myShiftTrades.single), isTrue);
        expect(model.pendingTradeOn(mine)?.id, 1);
      },
    );

    test(
      'a gift that leaves somebody below the minimum needs a Manager',
      () async {
        final model = viewModel();
        await model.load();
        final ottoKeeper = model.colleagues.single;

        // Hilda has 3: giving 1 leaves 2.
        expect(model.needsApproval(1, 0, ottoKeeper), isTrue);
        // An even swap loses nobody a room.
        expect(model.needsApproval(1, 1, ottoKeeper), isFalse);
        // Otto has 2: taking 1 of his for nothing leaves him 1.
        expect(model.needsApproval(1, 2, ottoKeeper), isTrue);
      },
    );

    test('a receptionist reads no rooms', () async {
      final model = viewModel(role: StaffRole.receptionist);
      await model.load();

      expect(model.hasRooms, isFalse);
      expect(model.myRooms, isEmpty);
    });

    test('a refused step gives the text of its code', () async {
      planning.changeFailure = const ApiFailure(FailureKind.rejected, [
        'shift_trade.expired',
      ]);
      final model = viewModel();
      await model.load();

      final outcome = await model.giveAway(model.myShifts.first);

      expect(outcome.saved, isFalse);
      expect(outcome.message, contains('24 hours'));
    });
  });

  group('MyWorkScreen', () {
    Future<void> show(WidgetTester tester, MyWorkViewModel model) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: MyWorkScreen(viewModel: model)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('gives an own shift away from its menu', (tester) async {
      await show(tester, viewModel());

      await tester.tap(find.byKey(const ValueKey('shiftMenu-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giveAway-1')));
      await tester.pumpAndSettle();

      expect(planning.calls, ['offer:1:null']);
      expect(find.textContaining('Offered'), findsOneWidget);
    });

    testWidgets('offers a swap for a shift of a colleague', (tester) async {
      await show(tester, viewModel());

      await tester.tap(find.byKey(const ValueKey('shiftMenu-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('swap-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('swapOption-2')));
      await tester.pumpAndSettle();

      expect(planning.calls, ['offer:1:2']);
    });

    testWidgets('takes a shift that a colleague gives away', (tester) async {
      planning.shiftTrades = [
        ShiftTrade(
          id: 5,
          shift: shift(4, nora, 5),
          offeredById: nora,
          offeredByName: 'Nora',
          state: TradeState.open,
          isClosed: false,
        ),
      ];
      await show(tester, viewModel());

      await tester.tap(find.byKey(const ValueKey('take-5')));
      await tester.pumpAndSettle();

      expect(planning.calls, ['shift-take:5']);
      expect(find.text(Strings.tradeStepDone(TradeStep.take)), findsOneWidget);
    });

    testWidgets('gives rooms to a colleague and warns about the minimum', (
      tester,
    ) async {
      await show(tester, viewModel());

      await tester.tap(find.text(Strings.roomsTab));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('myRoom-101')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tradeRooms')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tradeColleague')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otto Lund (2)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('give-103')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('needsManager')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sendRoomTrade')));
      await tester.pumpAndSettle();

      expect(planning.calls, ['offerRooms:$otto:103:']);
      expect(find.text('Sent to Otto Lund.'), findsOneWidget);
    });

    testWidgets('accepts rooms that a colleague offers', (tester) async {
      planning.roomTrades = const [
        RoomTrade(
          id: 4,
          fromStaffId: otto,
          fromName: 'Otto Lund',
          toStaffId: me,
          toName: 'Hilda Berg',
          give: [TradedRoom(roomId: 201, roomNumber: '201')],
          take: [],
          state: TradeState.open,
        ),
      ];
      await show(tester, viewModel());

      await tester.tap(find.text(Strings.roomsTab));
      await tester.pumpAndSettle();
      expect(find.text('You get 201'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('roomTrade-4-primary')));
      await tester.pumpAndSettle();

      expect(planning.calls, ['rooms-accept:4']);
    });

    testWidgets('a session without the account key asks to sign in again', (
      tester,
    ) async {
      await show(
        tester,
        MyWorkViewModel(
          planning: planning,
          session: validSession(staffId: 0),
          now: () => testNow,
        ),
      );

      expect(find.text(Strings.signInAgainForWork), findsOneWidget);
    });
  });
}
