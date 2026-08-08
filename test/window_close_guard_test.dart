// Widget tests for SolidWindowCloseGuard as wired up by the place editors —
// the window-close confirmation path (save / discard / keep editing).
//
// Runs without a live Pod: only rendering / state behaviour.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:solidui/solidui.dart';

import 'package:geopod/models/place.dart';
import 'package:geopod/widgets/add_place_form.dart';
import 'package:geopod/widgets/locations/edit_place_dialog.dart';

Place samplePlace() => Place(
  id: 'p1',
  lat: -35.2809,
  lng: 149.13,
  title: 'Canberra',
  note: 'Original note.',
  timestamp: '2026-08-08T10:00:00.000Z',
  address: 'Canberra ACT',
);

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The Save button of the solidui unsaved-changes prompt, distinguished from
/// the editor's own Save button underneath it.

Finder promptSave() => find.widgetWithText(FilledButton, 'Save');

void main() {
  group('EditPlaceDialog', () {
    testWidgets('resolveAll succeeds with no prompt when nothing changed', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(EditPlaceDialog(place: samplePlace())));
      await tester.pumpAndSettle();
      expect(await SolidWindowCloseGuard.resolveAll(), isTrue);
      expect(find.text('Unsaved changes'), findsNothing);
    });

    testWidgets('resolveAll prompts and resolves true on Discard', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(EditPlaceDialog(place: samplePlace())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New title');
      await tester.pump();

      final future = SolidWindowCloseGuard.resolveAll();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(await future, isTrue);
    });

    testWidgets('resolveAll prompts and resolves false on Keep editing', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(EditPlaceDialog(place: samplePlace())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New title');
      await tester.pump();

      final future = SolidWindowCloseGuard.resolveAll();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(await future, isFalse);
      // The editor is still open with the unsaved title intact.
      expect(find.text('New title'), findsOneWidget);
    });

    // Regression: the dialog used to pop its result and leave the caller to
    // persist it. There was nothing for the guard to await, so the window was
    // destroyed mid-write and the edit was lost despite tapping Save.
    testWidgets('window-close Save waits for the Pod write to finish', (
      tester,
    ) async {
      final podWrite = Completer<void>();
      var written = false;

      await tester.pumpWidget(
        wrap(
          EditPlaceDialog(
            place: samplePlace(),
            onSave: (place) async {
              await podWrite.future;
              written = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New title');
      await tester.pump();

      var resolved = false;
      final future = SolidWindowCloseGuard.resolveAll()
        ..then((_) => resolved = true);
      await tester.pumpAndSettle();

      await tester.tap(promptSave());
      await tester.pumpAndSettle();

      // The Pod write is still in flight, so the guard must NOT have resolved
      // — otherwise the caller would destroy the window and lose the edit.
      expect(resolved, isFalse);
      expect(written, isFalse);

      podWrite.complete();
      await tester.pumpAndSettle();

      expect(await future, isTrue);
      expect(written, isTrue);
    });

    testWidgets('editor unregisters its resolver on dispose', (tester) async {
      await tester.pumpWidget(wrap(EditPlaceDialog(place: samplePlace())));
      await tester.pumpAndSettle();
      await tester.pumpWidget(wrap(const SizedBox()));
      await tester.pumpAndSettle();
      // No editor left registered, so nothing to resolve.
      expect(await SolidWindowCloseGuard.resolveAll(), isTrue);
    });

    // Regression: the editor used to be marked clean before the write landed,
    // so a failed Pod write left it looking saved — Save disabled and the
    // window-close prompt silenced, losing the edit.
    testWidgets('a failed save leaves the edit unsaved and still prompting', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          EditPlaceDialog(
            place: samplePlace(),
            onSave: (place) async => throw Exception('pod unreachable'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New title');
      await tester.pump();

      // Save via the window-close prompt.
      final future = SolidWindowCloseGuard.resolveAll();
      await tester.pumpAndSettle();
      await tester.tap(promptSave());
      await tester.pumpAndSettle();

      // The whole point: a failed write must abort the close. Returning true
      // here destroys the window and loses the edit, with no second call to
      // notice anything was wrong.
      expect(await future, isFalse);
      expect(
        SolidWriteFailures.latest.value,
        contains('Failed saving the place.'),
      );

      // The write failed, so the editor must still consider itself dirty: a
      // second close attempt has to prompt again rather than discard silently.
      final second = SolidWindowCloseGuard.resolveAll();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(await second, isTrue);
      SolidWriteFailures.clear();
    });

    // Regression: the Save button used to pop the dialog and hand the result
    // to the caller, so a failed Pod write closed the editor and lost the
    // edit with nothing but a transient snackbar to say so.
    testWidgets('the Save button keeps the dialog open when the write fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          EditPlaceDialog(
            place: samplePlace(),
            onSave: (place) async => throw Exception('pod unreachable'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New title');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('New title'), findsOneWidget);
      expect(
        SolidWriteFailures.latest.value,
        contains('Failed saving the place.'),
      );
      SolidWriteFailures.clear();
    });

    // Save is only offered as a real option when the edit can actually be
    // written; an empty title aborts the close instead of discarding the work.
    testWidgets('Save with an empty title keeps the editor open', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(EditPlaceDialog(place: samplePlace())));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      final future = SolidWindowCloseGuard.resolveAll();
      await tester.pumpAndSettle();
      await tester.tap(promptSave());
      await tester.pumpAndSettle();
      expect(await future, isFalse);
    });
  });

  group('AddPlaceForm', () {
    // No initial coordinates: nothing triggers the address lookup, so the
    // form stays offline for the test.
    Widget addForm() => wrap(const AddPlaceForm(returnWidget: SizedBox()));

    testWidgets('resolveAll succeeds with no prompt on an untouched form', (
      tester,
    ) async {
      await tester.pumpWidget(addForm());
      await tester.pumpAndSettle();
      expect(await SolidWindowCloseGuard.resolveAll(), isTrue);
      expect(find.text('Unsaved changes'), findsNothing);
    });

    testWidgets('resolveAll prompts once a title is typed', (tester) async {
      await tester.pumpWidget(addForm());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New place');
      await tester.pump();

      final future = SolidWindowCloseGuard.resolveAll();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(await future, isTrue);
    });

    testWidgets('form unregisters its resolver on dispose', (tester) async {
      await tester.pumpWidget(addForm());
      await tester.pumpAndSettle();
      await tester.pumpWidget(wrap(const SizedBox()));
      await tester.pumpAndSettle();
      expect(await SolidWindowCloseGuard.resolveAll(), isTrue);
    });

    // Regression: a failed Pod write used to resolve the guard true anyway,
    // so the window was destroyed and the new place lost.
    testWidgets('a failed save aborts the close and keeps the form', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AddPlaceForm(
            initialLatitude: -35.2809,
            initialLongitude: 149.13,
            returnWidget: const SizedBox(),
            onSave: (result) async => throw Exception('pod unreachable'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New place');
      await tester.pump();

      final future = SolidWindowCloseGuard.resolveAll();
      await tester.pumpAndSettle();
      await tester.tap(promptSave());
      await tester.pumpAndSettle();

      expect(await future, isFalse);
      expect(
        SolidWriteFailures.latest.value,
        contains('Failed saving the place.'),
      );
      // Still on screen with everything the user typed.
      expect(find.text('New place'), findsOneWidget);
      SolidWriteFailures.clear();
    });

    // The Add Place button must not close over a write that never landed.
    testWidgets('the Add Place button keeps the form open when it fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          AddPlaceForm(
            initialLatitude: -35.2809,
            initialLongitude: 149.13,
            returnWidget: const SizedBox(),
            onSave: (result) async => throw Exception('pod unreachable'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New place');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Place'));
      await tester.pumpAndSettle();

      expect(find.text('New place'), findsOneWidget);
      expect(
        SolidWriteFailures.latest.value,
        contains('Failed saving the place.'),
      );
      SolidWriteFailures.clear();
    });
  });
}
