import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobil_application/domain/entities/room.dart';
import 'package:mobil_application/domain/entities/staff_session.dart';
import 'package:mobil_application/domain/result.dart';
import 'package:mobil_application/presentation/features/rooms/room_service_notes_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_model.dart';
import 'package:mobil_application/presentation/features/rooms/room_view_screen.dart';
import 'package:mobil_application/presentation/shared/strings.dart';

import '../../support/fakes.dart';

const ApiFailure _undoTooLate = ApiFailure(FailureKind.rejected, [
  'room_service_note.undo_window_closed',
]);

void main() {
  late FakeRoomServiceNoteRepository notes;

  setUp(() {
    notes = FakeRoomServiceNoteRepository(
      current: [
        serviceNote(id: 1, text: 'The tap drips'),
        serviceNote(id: 2, roomId: 9, text: 'Another room'),
      ],
      history: [
        serviceNote(id: 3, text: 'The lamp was broken', doneBy: 'tom'),
        serviceNote(id: 4, roomId: 9, text: 'Another room', doneBy: 'tom'),
      ],
    );
  });

  RoomServiceNotesViewModel viewModel({
    StaffRole role = StaffRole.housekeeping,
  }) => RoomServiceNotesViewModel(notes: notes, roomId: 1, role: role);

  group('RoomServiceNotesViewModel', () {
    test('load shows only the notes of the room', () async {
      final model = viewModel();

      await model.load();

      expect(model.notes.map((n) => n.id), [1]);
      expect(model.errorMessage, isNull);
    });

    test('loadHistory shows only the history of the room', () async {
      final model = viewModel();

      await model.loadHistory();

      expect(model.history.map((n) => n.id), [3]);
      expect(model.hasReadHistory, isTrue);
    });

    test('report sends the trimmed text and shows the new note', () async {
      final model = viewModel();

      final written = await model.report('  No hot water \n');

      expect(written, isTrue);
      expect(notes.changes, ['create:1:No hot water']);
      expect(model.notes.map((n) => n.text), ['The tap drips', 'No hot water']);
    });

    test('an empty report is not sent', () async {
      final model = viewModel();

      expect(await model.report('   '), isFalse);

      expect(notes.changes, isEmpty);
    });

    test('toggleDone marks an open note and undoes a done one', () async {
      final model = viewModel();
      await model.load();

      await model.toggleDone(model.notes.single);
      expect(model.notes.single.doneBy, 'hilda');

      await model.toggleDone(model.notes.single);
      expect(model.notes.single.isDone, isFalse);
      expect(notes.changes, ['markDone:1', 'undoDone:1']);
    });

    test('an undo too late says why and shows the note gone', () async {
      notes.current = [serviceNote(id: 1, doneBy: 'tom')];
      final model = viewModel();
      await model.load();

      // The five minutes passed since the last read.
      notes
        ..current = []
        ..changeFailure = _undoTooLate;
      await model.toggleDone(model.notes.single);

      expect(model.errorMessage, contains('Only a manager'));
      expect(model.notes, isEmpty);
      expect(model.isBusy, isFalse);
    });

    test('reopen returns the note and reads both lists again', () async {
      final model = viewModel(role: StaffRole.manager);
      await model.load();
      await model.loadHistory();

      final reopened = await model.reopen(model.history.single);

      expect(reopened, isTrue);
      expect(notes.changes, ['reopen:3']);
      expect(model.history, isEmpty);
      expect(model.notes.map((n) => n.id), [1, 3]);
    });

    test('a refused reopen says so and changes nothing', () async {
      final model = viewModel();
      await model.loadHistory();
      notes.changeFailure = const ApiFailure(FailureKind.forbidden);

      final reopened = await model.reopen(model.history.single);

      expect(reopened, isFalse);
      expect(model.errorMessage, 'Your role may not do that.');
      expect(model.history.map((n) => n.id), [3]);
    });

    test('refresh updates the list without touching the message', () async {
      final model = viewModel();
      await model.load();
      notes.changeFailure = _undoTooLate;
      await model.toggleDone(model.notes.single);
      final message = model.errorMessage;
      notes.current = [];

      await model.refresh();

      expect(model.notes, isEmpty);
      expect(model.errorMessage, message);
    });

    test('a failed refresh keeps the notes and shows nothing', () async {
      final model = viewModel();
      await model.load();
      notes.failure = const ApiFailure(FailureKind.network);

      await model.refresh();

      expect(model.notes.map((n) => n.id), [1]);
      expect(model.errorMessage, isNull);
    });

    test('a refresh from before a change does not undo what it shows', () async {
      final model = viewModel();
      await model.load();

      // The refresh has read the state before the change, and answers after it.
      final answer = Completer<void>();
      notes.beforeReadCurrent = () => answer.future;
      final refresh = model.refresh();
      notes.beforeReadCurrent = null;

      await model.toggleDone(model.notes.single);
      expect(model.notes.single.isDone, isTrue);

      answer.complete();
      await refresh;

      expect(model.notes.single.isDone, isTrue);
    });

    test(
      'a server without the route says so, not that the room is gone',
      () async {
        notes.failure = const ApiFailure(FailureKind.notFound);
        final model = viewModel();

        await model.load();

        expect(model.errorMessage, contains('not available on this server'));
      },
    );

    test('a room the API cannot find is still told as such', () async {
      notes.changeFailure = const ApiFailure(FailureKind.notFound, [
        'room.not_found',
      ]);
      final model = viewModel();

      await model.report('The tap drips');

      expect(model.errorMessage, 'The room was not found.');
    });

    test('the role decides what is offered', () {
      expect(viewModel().canWrite, isTrue);
      expect(viewModel().canReopen, isFalse);
      expect(viewModel(role: StaffRole.manager).canWrite, isTrue);
      expect(viewModel(role: StaffRole.manager).canReopen, isTrue);
      expect(viewModel(role: StaffRole.receptionist).canWrite, isFalse);
      expect(viewModel(role: StaffRole.receptionist).canReopen, isFalse);
    });
  });

  group('the room screen', () {
    late FakeRoomRepository rooms;
    late RoomViewModel roomModel;

    setUp(() {
      rooms = FakeRoomRepository([room()]);
      roomModel = RoomViewModel(rooms: rooms, room: rooms.rooms.single);
    });

    Future<void> show(
      WidgetTester tester, {
      StaffRole role = StaffRole.housekeeping,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomViewScreen(
            viewModel: roomModel,
            notes: viewModel(role: role),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Checkbox box(WidgetTester tester, int id) =>
        tester.widget<Checkbox>(find.byKey(ValueKey('noteDone-$id')));

    Future<void> openHistory(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const ValueKey('serviceHistory')));
      await tester.tap(find.byKey(const ValueKey('serviceHistory')));
      await tester.pumpAndSettle();
    }

    testWidgets('a note shows its text, who wrote it and an open box', (
      tester,
    ) async {
      await show(tester);

      expect(find.text('The tap drips'), findsOneWidget);
      expect(find.textContaining('Written by hilda'), findsOneWidget);
      expect(find.textContaining('Done by'), findsNothing);
      expect(box(tester, 1).value, isFalse);
      expect(find.text('Another room'), findsNothing);
    });

    testWidgets(
      'writing a note sends it, empties the field and reads the room',
      (tester) async {
        await show(tester);
        rooms.rooms = [room(housekeeping: HousekeepingStatus.serviceRequired)];

        final report = find.byKey(const ValueKey('reportNote'));
        await tester.ensureVisible(report);
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(report).onPressed, isNull);

        await tester.enterText(
          find.byKey(const ValueKey('noteField')),
          'No heat',
        );
        await tester.pump();
        await tester.tap(report);
        await tester.pumpAndSettle();

        expect(notes.changes, ['create:1:No heat']);
        expect(find.text('No heat'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('noteField')))
              .controller
              ?.text,
          isEmpty,
        );
        expect(find.text('Service needed'), findsOneWidget);
      },
    );

    testWidgets('a refused note keeps what was written', (tester) async {
      await show(tester);
      notes.changeFailure = const ApiFailure(FailureKind.rejected, [
        'room_service_note.text_too_long',
      ]);

      await tester.enterText(find.byKey(const ValueKey('noteField')), 'Words');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('reportNote')));
      await tester.tap(find.byKey(const ValueKey('reportNote')));
      await tester.pumpAndSettle();

      expect(find.text('The note is too long.'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
    });

    testWidgets('a receptionist has no field, but can tick a note as done', (
      tester,
    ) async {
      await show(tester, role: StaffRole.receptionist);

      expect(find.byKey(const ValueKey('noteField')), findsNothing);
      expect(find.byKey(const ValueKey('reportNote')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('noteDone-1')));
      await tester.pumpAndSettle();

      expect(notes.changes, ['markDone:1']);
      expect(box(tester, 1).value, isTrue);
    });

    testWidgets('a ticked note says who did it and can be unticked', (
      tester,
    ) async {
      await show(tester);

      await tester.tap(find.byKey(const ValueKey('noteDone-1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Done by hilda'), findsOneWidget);
      expect(find.textContaining('Can be unticked until'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('noteDone-1')));
      await tester.pumpAndSettle();

      expect(notes.changes, ['markDone:1', 'undoDone:1']);
      expect(box(tester, 1).value, isFalse);
    });

    testWidgets('an untick too late shows why and the note leaves the list', (
      tester,
    ) async {
      notes.current = [serviceNote(id: 1, doneBy: 'tom')];
      await show(tester);

      notes
        ..current = []
        ..changeFailure = _undoTooLate;
      await tester.tap(find.byKey(const ValueKey('noteDone-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('notesError')), findsOneWidget);
      expect(find.byKey(const ValueKey('noteDone-1')), findsNothing);
    });

    testWidgets('the notes are read again while the screen is open', (
      tester,
    ) async {
      await show(tester);
      final reads = notes.currentReads;
      notes.current = [
        ...notes.current,
        serviceNote(id: 5, text: 'From a colleague'),
      ];

      await tester.pump(RoomViewScreen.notesRefreshInterval);
      await tester.pump();

      expect(notes.currentReads, reads + 1);
      expect(find.text('From a colleague'), findsOneWidget);
    });

    testWidgets('leaving the screen stops the reading', (tester) async {
      await show(tester);
      await tester.pumpWidget(const SizedBox());
      final reads = notes.currentReads;

      await tester.pump(RoomViewScreen.notesRefreshInterval * 2);

      expect(notes.currentReads, reads);
    });

    testWidgets('the screen fits a small phone with a long note', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      notes.current = [
        serviceNote(
          id: 1,
          text: List.filled(60, 'word').join(' '),
          writtenBy: 'a-member-of-staff-with-a-long-user-name',
          doneBy: 'another-member-of-staff-with-a-long-user-name',
        ),
      ];

      await show(tester);

      expect(tester.takeException(), isNull);
    });

    group('the history', () {
      testWidgets('shows the finished service and who did it', (tester) async {
        await show(tester);

        await openHistory(tester);

        expect(find.text('The lamp was broken'), findsOneWidget);
        expect(find.textContaining('Written by hilda'), findsOneWidget);
        expect(find.textContaining('Done by tom'), findsOneWidget);
        expect(find.textContaining('Can be unticked'), findsNothing);
        expect(box(tester, 3).value, isTrue);
      });

      testWidgets('says so when it is empty', (tester) async {
        notes.history = [];
        await show(tester);

        await openHistory(tester);

        expect(find.text(Strings.noServiceHistory), findsOneWidget);
      });

      testWidgets('is locked for housekeeping and a receptionist', (
        tester,
      ) async {
        for (final role in [StaffRole.housekeeping, StaffRole.receptionist]) {
          await show(tester, role: role);
          await openHistory(tester);

          expect(box(tester, 3).onChanged, isNull, reason: role.name);

          await tester.pageBack();
          await tester.pumpAndSettle();
        }
      });

      testWidgets('a manager unticks a note and it is open under the room', (
        tester,
      ) async {
        rooms.rooms = [room(housekeeping: HousekeepingStatus.serviceRequired)];
        await show(tester, role: StaffRole.manager);
        await openHistory(tester);

        await tester.tap(find.byKey(const ValueKey('noteDone-3')));
        await tester.pumpAndSettle();

        expect(notes.changes, ['reopen:3']);
        expect(find.text(Strings.noServiceHistory), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('The lamp was broken'), findsOneWidget);
        expect(box(tester, 3).value, isFalse);
        expect(find.text('Service needed'), findsOneWidget);
      });

      testWidgets('shows a failure', (tester) async {
        await show(tester);
        notes.failure = const ApiFailure(FailureKind.network);

        await openHistory(tester);

        expect(find.byKey(const ValueKey('historyError')), findsOneWidget);
        expect(find.text(Strings.noServiceHistory), findsNothing);
      });
    });
  });
}
