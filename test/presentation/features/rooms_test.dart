import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/features/rooms/room_overview_screen.dart';
import 'package:mobil_application/presentation/features/rooms/room_overview_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_screen.dart';
import 'package:mobil_application/presentation/session/session_controller.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

import '../../support/fakes.dart';

void main() {
  late FakeRoomRepository rooms;

  setUp(() {
    rooms = FakeRoomRepository([
      room(id: 2, number: '201', floor: 2),
      room(
        id: 1,
        number: '102',
        floor: 1,
        housekeeping: HousekeepingStatus.dailyCleaningDue,
        actions: const RoomActions(canStartCleaning: true),
      ),
      room(id: 3, number: '101', floor: 1),
    ]);
  });

  group('RoomOverviewViewModel', () {
    test('load shows the rooms by floor and then by number', () async {
      final viewModel = RoomOverviewViewModel(rooms: rooms);

      await viewModel.load();

      expect(viewModel.state, RoomOverviewState.ready);
      expect(viewModel.rooms.map((r) => r.roomNumber), ['101', '102', '201']);
    });

    test('a failure is shown as a message, not thrown', () async {
      rooms.failure = const ApiFailure(FailureKind.network);
      final viewModel = RoomOverviewViewModel(rooms: rooms);

      await viewModel.load();

      expect(viewModel.state, RoomOverviewState.error);
      expect(viewModel.errorMessage, contains('cannot be reached'));
    });

    test('load after a failure recovers', () async {
      rooms.failure = const ApiFailure(FailureKind.server);
      final viewModel = RoomOverviewViewModel(rooms: rooms);
      await viewModel.load();

      rooms.failure = null;
      await viewModel.load();

      expect(viewModel.state, RoomOverviewState.ready);
      expect(viewModel.errorMessage, isNull);
    });
  });

  group('RoomViewModel', () {
    test('the actions are those that the room allows, in cleaning order', () {
      final viewModel = RoomViewModel(
        rooms: rooms,
        room: room(
          actions: const RoomActions(
            canCompleteCleaning: true,
            canMarkDailyCleaningDue: true,
            canReportServiceNeeded: true,
          ),
        ),
      );

      expect(viewModel.actions, [
        RoomAction.markDailyCleaningDue,
        RoomAction.completeCleaning,
        RoomAction.reportServiceNeeded,
      ]);
    });

    test(
      'perform sends the action and shows the room as it is afterwards',
      () async {
        rooms.onPerform = (id, action, requiresCleaning) => room(
          id: id,
          number: '102',
          housekeeping: HousekeepingStatus.cleaningInProgress,
          actions: const RoomActions(canCompleteCleaning: true),
        );
        final viewModel = RoomViewModel(rooms: rooms, room: rooms.rooms[1]);

        await viewModel.perform(RoomAction.startCleaning);

        expect(rooms.performed, ['1:startCleaning:false']);
        expect(
          viewModel.room.housekeepingStatus,
          HousekeepingStatus.cleaningInProgress,
        );
        expect(viewModel.actions, [RoomAction.completeCleaning]);
      },
    );

    test('complete service passes whether cleaning follows', () async {
      final viewModel = RoomViewModel(rooms: rooms, room: rooms.rooms[1]);

      await viewModel.perform(
        RoomAction.completeService,
        requiresCleaning: true,
      );

      expect(rooms.performed, ['1:completeService:true']);
    });

    test('a refused action keeps the room and shows why', () async {
      rooms.failure = const ApiFailure(FailureKind.rejected);
      final viewModel = RoomViewModel(rooms: rooms, room: rooms.rooms[1]);

      await viewModel.perform(RoomAction.startCleaning);

      expect(viewModel.errorMessage, 'That is not possible with the room now.');
      expect(viewModel.room.roomId, 1);
      expect(viewModel.isBusy, isFalse);
    });

    test('a role without the permission is told so', () async {
      rooms.failure = const ApiFailure(FailureKind.forbidden);
      final viewModel = RoomViewModel(rooms: rooms, room: rooms.rooms[1]);

      await viewModel.perform(RoomAction.startCleaning);

      expect(viewModel.errorMessage, 'Your role may not do that.');
    });
  });

  group('RoomOverviewScreen', () {
    late SessionController session;

    setUp(() async {
      session = SessionController(
        store: FakeSessionStore(validSession()),
        now: () => testNow,
      );
      await session.restore();
    });

    Future<void> show(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: RoomOverviewScreen(
          viewModel: RoomOverviewViewModel(rooms: rooms),
          rooms: rooms,
          session: session,
        ),
      ),
    );

    testWidgets('shows a tile for every room and who is signed in', (
      tester,
    ) async {
      await show(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('room-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('room-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('room-3')), findsOneWidget);
      expect(find.text('hilda (Housekeeping)'), findsOneWidget);
      expect(find.text('Daily cleaning due'), findsOneWidget);
    });

    testWidgets('a failure shows the message and a way to try again', (
      tester,
    ) async {
      rooms.failure = const ApiFailure(FailureKind.network);
      await show(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('roomsError')), findsOneWidget);

      rooms.failure = null;
      await tester.tap(find.text(Strings.retry));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('room-1')), findsOneWidget);
    });

    testWidgets('sign out ends the session', (tester) async {
      await show(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('signOut')));
      await tester.pump();

      expect(session.session, isNull);
    });

    testWidgets(
      'a room opens, its action runs, and the overview is read again',
      (tester) async {
        rooms.onPerform = (id, action, requiresCleaning) => room(
          id: id,
          number: '102',
          housekeeping: HousekeepingStatus.cleaningInProgress,
        );
        await show(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('room-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('action-startCleaning')));
        await tester.pumpAndSettle();
        expect(find.text('Being cleaned'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Being cleaned'), findsOneWidget);
        expect(rooms.performed, ['1:startCleaning:false']);
      },
    );
  });

  group('RoomViewScreen', () {
    Future<RoomViewModel> show(WidgetTester tester, Room room) async {
      rooms.rooms = [room];
      final viewModel = RoomViewModel(rooms: rooms, room: room);
      await tester.pumpWidget(
        MaterialApp(home: RoomViewScreen(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();
      return viewModel;
    }

    testWidgets('offers a button only for each action the room allows', (
      tester,
    ) async {
      await show(
        tester,
        room(
          actions: const RoomActions(
            canStartCleaning: true,
            canReportServiceNeeded: true,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('action-startCleaning')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('action-reportServiceNeeded')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('action-completeCleaning')),
        findsNothing,
      );
    });

    testWidgets('says so when nothing can be done', (tester) async {
      await show(tester, room());

      expect(find.text(Strings.nothingToDo), findsOneWidget);
    });

    testWidgets('completing a service asks whether cleaning follows', (
      tester,
    ) async {
      await show(
        tester,
        room(actions: const RoomActions(canCompleteService: true)),
      );

      await tester.tap(find.byKey(const ValueKey('action-completeService')));
      await tester.pumpAndSettle();
      expect(find.text(Strings.cleaningFollows), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cleaningFollowsYes')));
      await tester.pumpAndSettle();

      expect(rooms.performed, ['1:completeService:true']);
    });

    testWidgets('cancelling the question does nothing', (tester) async {
      await show(
        tester,
        room(actions: const RoomActions(canCompleteService: true)),
      );

      await tester.tap(find.byKey(const ValueKey('action-completeService')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();

      expect(rooms.performed, isEmpty);
    });

    testWidgets('a refused action shows the message on the screen', (
      tester,
    ) async {
      await show(
        tester,
        room(actions: const RoomActions(canStartCleaning: true)),
      );
      rooms.failure = const ApiFailure(FailureKind.rejected);

      await tester.tap(find.byKey(const ValueKey('action-startCleaning')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('roomError')), findsOneWidget);
    });
  });
}
