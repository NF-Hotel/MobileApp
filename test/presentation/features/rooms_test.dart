import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
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
      room(number: 1, name: '101', cleaners: ['Hilda Berg']),
      room(number: 2, name: 'Suite', status: RoomStatus.needsCleaning),
    ]);
  });

  RoomViewModel viewModelFor(
    Room room, {
    StaffSession? viewer,
    DateTime? now,
  }) => RoomViewModel(
    rooms: rooms,
    room: room,
    viewer: viewer ?? validSession(),
    now: () => now ?? testNow,
  );

  group('RoomOverviewViewModel', () {
    test('load shows the rooms in the order of the API', () async {
      final viewModel = RoomOverviewViewModel(rooms: rooms);

      await viewModel.load();

      expect(viewModel.state, RoomOverviewState.ready);
      expect(viewModel.rooms.map((r) => r.name), ['101', 'Suite']);
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
    test('setStatus changes the room after the API agrees', () async {
      final viewModel = viewModelFor(rooms.rooms.first);

      final done = await viewModel.setStatus(RoomStatus.dailyCleaning);

      expect(done, isTrue);
      expect(viewModel.room.status, RoomStatus.dailyCleaning);
      expect(rooms.calls, ['setStatus:1:dailyCleaning']);
    });

    test('a refused status keeps the room as it was', () async {
      rooms.failure = const ApiFailure(FailureKind.forbidden);
      final viewModel = viewModelFor(rooms.rooms.first);

      final done = await viewModel.setStatus(RoomStatus.needsMaintenance);

      expect(done, isFalse);
      expect(viewModel.room.status, RoomStatus.clean);
      expect(viewModel.errorMessage, 'You may not do that.');
    });

    test('adding a note reads the notes again; empty is not sent', () async {
      final viewModel = viewModelFor(rooms.rooms.first);

      expect(await viewModel.addNote('   '), isFalse);
      expect(await viewModel.addNote(' Towels '), isTrue);

      expect(rooms.calls, ['addNote:1:Towels']);
      expect(viewModel.notes.single.body, 'Towels');
    });

    test('the author may delete a note for ten minutes only', () {
      final viewModel = viewModelFor(
        rooms.rooms.first,
        now: testNow.add(const Duration(minutes: 9)),
      );
      final later = viewModelFor(
        rooms.rooms.first,
        now: testNow.add(const Duration(minutes: 10)),
      );

      expect(viewModel.canDelete(note()), isTrue);
      expect(viewModel.canDelete(note(createdBy: 'ole@hotel.test')), isFalse);
      expect(later.canDelete(note()), isFalse);
    });

    test('an admin may delete and untick any note at any time', () {
      final viewModel = viewModelFor(
        rooms.rooms.first,
        viewer: validSession(role: StaffRole.admin, email: 'boss@hotel.test'),
        now: testNow.add(const Duration(days: 3)),
      );
      final resolved = note(resolvedBy: 'ole@hotel.test', resolvedAt: testNow);

      expect(viewModel.canDelete(note()), isTrue);
      expect(viewModel.canToggle(resolved), isTrue);
    });

    test('anyone may tick; only the one who ticked may untick, briefly', () {
      final viewModel = viewModelFor(
        rooms.rooms.first,
        now: testNow.add(const Duration(minutes: 5)),
      );

      expect(viewModel.canToggle(note(createdBy: 'ole@hotel.test')), isTrue);
      expect(
        viewModel.canToggle(
          note(resolvedBy: 'hilda@hotel.test', resolvedAt: testNow),
        ),
        isTrue,
      );
      expect(
        viewModel.canToggle(
          note(resolvedBy: 'ole@hotel.test', resolvedAt: testNow),
        ),
        isFalse,
      );
    });
  });

  group('RoomOverviewScreen', () {
    Future<SessionController> show(WidgetTester tester) async {
      final session = SessionController(
        store: FakeSessionStore(validSession()),
        now: () => testNow,
      );
      await session.restore();
      await tester.pumpWidget(
        MaterialApp(
          home: RoomOverviewScreen(
            viewModel: RoomOverviewViewModel(rooms: rooms),
            rooms: rooms,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return session;
    }

    testWidgets('shows each room with its state and cleaners', (tester) async {
      await show(tester);

      expect(find.byKey(const ValueKey('room-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('room-2')), findsOneWidget);
      expect(find.text('Needs cleaning'), findsOneWidget);
      expect(find.text('Hilda Berg'), findsOneWidget);
      expect(find.text('Hilda Berg (Cleaner)'), findsOneWidget);
    });

    testWidgets('a failure shows the message and a retry', (tester) async {
      rooms.failure = const ApiFailure(FailureKind.network);
      await show(tester);

      expect(find.byKey(const ValueKey('roomsError')), findsOneWidget);
      rooms.failure = null;
      await tester.tap(find.text(Strings.retry));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('room-1')), findsOneWidget);
    });

    testWidgets('no rooms says so', (tester) async {
      rooms.rooms = [];
      await show(tester);

      expect(find.text(Strings.noRooms), findsOneWidget);
    });

    testWidgets('a status set in a room shows in the overview after', (
      tester,
    ) async {
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('room-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('status-needsMaintenance')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(rooms.calls, ['setStatus:1:needsMaintenance']);
      expect(find.text('Needs maintenance'), findsOneWidget);
    });
  });

  group('RoomViewScreen', () {
    Future<void> show(WidgetTester tester, RoomViewModel viewModel) async {
      await tester.pumpWidget(
        MaterialApp(home: RoomViewScreen(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the cleaners and the notes', (tester) async {
      rooms.notes[1] = [note(id: 7, body: 'Lamp is broken')];
      await show(tester, viewModelFor(rooms.rooms.first));

      expect(find.text('Hilda Berg'), findsOneWidget);
      expect(find.text('Lamp is broken'), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-7')), findsOneWidget);
    });

    testWidgets('a note is added and the field cleared', (tester) async {
      await show(tester, viewModelFor(rooms.rooms.first));
      expect(find.text(Strings.noNotes), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('newNote')), 'Towels');
      await tester.tap(find.byKey(const ValueKey('addNote')));
      await tester.pumpAndSettle();

      expect(rooms.calls, ['addNote:1:Towels']);
      expect(find.text('Towels'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('newNote')),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('ticking and deleting a note call the API', (tester) async {
      rooms.notes[1] = [note(id: 7)];
      await show(tester, viewModelFor(rooms.rooms.first));

      await tester.tap(find.byKey(const ValueKey('resolve-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-7')));
      await tester.pumpAndSettle();

      expect(rooms.calls, ['setResolved:1:7:true', 'deleteNote:1:7']);
      expect(find.text(Strings.noNotes), findsOneWidget);
    });

    testWidgets('a note of someone else has no delete button', (tester) async {
      rooms.notes[1] = [note(id: 7, createdBy: 'ole@hotel.test')];
      await show(tester, viewModelFor(rooms.rooms.first));

      expect(find.byKey(const ValueKey('delete-7')), findsNothing);
    });

    testWidgets('a refusal is shown on the screen', (tester) async {
      final viewModel = viewModelFor(rooms.rooms.first);
      await show(tester, viewModel);
      rooms.failure = const ApiFailure(FailureKind.forbidden);

      await tester.tap(find.byKey(const ValueKey('status-dailyCleaning')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('roomError')), findsOneWidget);
    });
  });
}
